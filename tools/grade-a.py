# grade-a.py -- grade T-REDO-PREPOST task A results.
#
# GSM: extract the number after ####, compare to gold.
# HumanEval: splice prompt + completion, exec it, run the official check().
# MMLU: extract a single letter, compare to gold.
#
# Data source: TASK-A/<arm>/results.jsonl (written by task-a.ps1)
# Output: TASK-A/score.json

import json
import os
import re
import sys
import traceback

HUMANEVAL_TESTS = {
    "HumanEval-0": '''
def check(candidate):
    assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.3) == True
    assert candidate([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.05) == False
    assert candidate([1.0, 2.0, 5.9, 4.0, 5.0], 0.95) == True
    assert candidate([1.0, 2.0, 5.9, 4.0, 5.0], 0.8) == False
    assert candidate([1.0, 2.0, 3.0, 4.0, 5.0, 2.0], 0.1) == True
    assert candidate([1.1, 2.2, 3.1, 4.1, 5.1], 1.0) == True
    assert candidate([1.1, 2.2, 3.1, 4.1, 5.1], 0.5) == False
''',
    "HumanEval-1": '''
def check(candidate):
    assert candidate('(()()) ((())) () ((())()())') == [
        '(()())', '((()))', '()', '((())()())'
    ]
    assert candidate('() (()) ((())) (((())))') == [
        '()', '(())', '((()))', '(((())))'
    ]
    assert candidate('(()(())((())))') == [
        '(()(())((())))'
    ]
    assert candidate('( ) (( )) (( )( ))') == ['()', '(())', '(()())']
''',
    "HumanEval-2": '''
def check(candidate):
    assert candidate(3.5) == 0.5
    assert abs(candidate(1.33) - 0.33) < 1e-6
    assert abs(candidate(123.456) - 0.456) < 1e-6
''',
    "HumanEval-3": '''
def check(candidate):
    assert candidate([]) == False
    assert candidate([1, 2, -3, 1, 2, -3]) == False
    assert candidate([1, 2, -4, 5]) == True
    assert candidate([1, -2, 2, -2, 5, -5, 4, -4]) == True
''',
}

FUNC_NAMES = {
    "HumanEval-0": "has_close_elements",
    "HumanEval-1": "separate_paren_groups",
    "HumanEval-2": "truncate_number",
    "HumanEval-3": "below_zero",
}


def grade_gsm(rec):
    out = rec.get("output") or ""
    m = re.findall(r"####\s*(-?[\d,\.]+)", out)
    if not m:
        return False, "no #### found"
    cand = m[-1].replace(",", "").rstrip(".")
    gold = str(rec["gold"]).replace(",", "")
    try:
        return (float(cand) == float(gold)), "cand=%s gold=%s" % (cand, gold)
    except Exception:
        return (cand == gold), "cand=%s gold=%s" % (cand, gold)


def grade_mmlu(rec):
    out = (rec.get("output") or "").strip()
    m = re.findall(r"\b([A-D])\b", out)
    cand = m[0] if m else None
    gold = str(rec["gold"]).strip().upper()
    return (cand == gold), "cand=%s gold=%s" % (cand, gold)


def grade_code(rec):
    pid = rec["id"]
    prompt = rec.get("prompt_used") or ""
    gen = rec.get("output") or ""
    test = HUMANEVAL_TESTS.get(pid)
    fname = FUNC_NAMES.get(pid)
    if not test or not fname:
        return False, "no test harness for %s" % pid
    src = prompt + "\n" + gen + "\n" + test + "\ncheck(%s)\n" % fname
    ns = {}
    try:
        exec(compile(src, "<candidate>", "exec"), ns)
        return True, "check() passed"
    except Exception as e:
        return False, "%s: %s" % (type(e).__name__, str(e)[:160])


def main(root):
    task_dir = os.path.join(root, "TASK-A")
    arms = [d for d in os.listdir(task_dir) if os.path.isdir(os.path.join(task_dir, d))]
    report = {"arms": {}, "generated_at": None}
    import datetime
    report["generated_at"] = datetime.datetime.now().isoformat()

    per_arm = {}
    for arm in sorted(arms):
        rp = os.path.join(task_dir, arm, "results.jsonl")
        if not os.path.exists(rp):
            continue
        recs = []
        # utf-8-sig: PowerShell 5.1 Add-Content -Encoding UTF8 writes a BOM, and json.loads
        # rejects it ("Unexpected UTF-8 BOM").
        with open(rp, "r", encoding="utf-8-sig") as f:
            for line in f:
                line = line.strip()
                if line:
                    recs.append(json.loads(line))
        detail = []
        correct = 0
        for rec in recs:
            kind = rec.get("kind")
            if kind == "gsm":
                ok, why = grade_gsm(rec)
            elif kind == "mmlu":
                ok, why = grade_mmlu(rec)
            elif kind == "code":
                ok, why = grade_code(rec)
            else:
                ok, why = False, "unknown kind"
            if ok:
                correct += 1
            detail.append({"id": rec["id"], "kind": kind, "ok": ok, "why": why,
                           "output_head": (rec.get("output") or "")[:200]})
        per_arm[arm] = {"total": len(recs), "correct": correct,
                        "accuracy": round(correct / len(recs), 3) if recs else None,
                        "detail": detail}
        report["arms"][arm] = per_arm[arm]

    # consistency between the two arms (identical outputs?)
    a1 = per_arm.get("A1-cache0", {}).get("detail", [])
    a2 = per_arm.get("A2-cache10752", {}).get("detail", [])
    if a1 and a2:
        same = sum(1 for x, y in zip(a1, a2) if x["output_head"] == y["output_head"])
        report["consistency"] = {"identical_outputs": same, "of": min(len(a1), len(a2))}
        acc1 = per_arm["A1-cache0"]["accuracy"]
        acc2 = per_arm["A2-cache10752"]["accuracy"]
        if acc1 is not None and acc2 is not None:
            report["accuracy_diff_pp"] = round(abs(acc1 - acc2) * 100, 1)
            report["verdict"] = (
                "PASS" if (report["accuracy_diff_pp"] <= 20 and same >= 7)
                else "DEGRADED (A0 perplexity is authoritative if they conflict)"
            )
    with open(os.path.join(task_dir, "score.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps({k: v for k, v in report.items() if k != "arms"}, ensure_ascii=False, indent=2))
    for arm, v in per_arm.items():
        print("%s: %d/%d correct (%.1f%%)" % (arm, v["correct"], v["total"], (v["accuracy"] or 0) * 100))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
