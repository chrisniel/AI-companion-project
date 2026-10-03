import argparse
import json
import sys
import os

def is_docs_only_file(filepath):
    # Docs allowlist: docs/**, *.md in repository root
    filepath = filepath.replace("\\", "/") # Normalize paths just in case
    if filepath.startswith("docs/"):
        return True
    if "/" not in filepath and filepath.endswith(".md"):
        return True
    return False

def classify(args):
    event = args.event
    
    # workflow_dispatch and master targets force Full CI override
    if event == "workflow_dispatch" or args.target_branch == "master":
        return {"needs_backend": "true", "needs_frontend": "true", "needs_contract": "true", "needs_docs": "true"}
        
    if not args.files_json:
        # Fallback to Full Verification
        return {"needs_backend": "true", "needs_frontend": "true", "needs_contract": "true", "needs_docs": "true"}
        
    try:
        files = json.loads(args.files_json)
    except Exception:
        # Fallback to Full Verification
        return {"needs_backend": "true", "needs_frontend": "true", "needs_contract": "true", "needs_docs": "true"}
        
    if not files:
        # No files (or empty diff) - Fallback to Full Verification to be safe
        return {"needs_backend": "true", "needs_frontend": "true", "needs_contract": "true", "needs_docs": "true"}
        
    needs_backend = False
    needs_frontend = False
    needs_contract = False
    needs_docs = False
    
    all_docs = True
    
    for f in files:
        f = f.replace("\\", "/")
        if is_docs_only_file(f):
            needs_docs = True
        else:
            all_docs = False
            
        if f.startswith("backend/"):
            needs_backend = True
            needs_contract = True
        elif f.startswith("frontend/"):
            needs_frontend = True
        elif f.startswith("contracts/") or f == "scripts/check_openapi_contract.py":
            needs_contract = True
        elif not is_docs_only_file(f):
            # Unknown unmapped (e.g. .github/**, android/**, scripts/**) forces Full Verification
            return {"needs_backend": "true", "needs_frontend": "true", "needs_contract": "true", "needs_docs": "true"}
            
    if all_docs:
        return {"needs_backend": "false", "needs_frontend": "false", "needs_contract": "false", "needs_docs": "true"}
        
    return {
        "needs_backend": "true" if needs_backend else "false",
        "needs_frontend": "true" if needs_frontend else "false",
        "needs_contract": "true" if needs_contract else "false",
        "needs_docs": "true" if needs_docs else "false",
    }

def gate(args):
    status = args.classifier_status
    if status != "success":
        print(f"FAIL: classifier status is '{status}' (must be 'success')")
        return False
        
    try:
        reqs = json.loads(args.requirements_json)
        results = json.loads(args.results_json)
    except Exception as e:
        print(f"FAIL: invalid JSON arguments - {e}")
        return False
        
    lane_map = {
        "backend": "needs_backend",
        "frontend": "needs_frontend",
        "contract": "needs_contract",
        "docs_integrity": "needs_docs"
    }
    
    all_passed = True
    
    for lane, req_key in lane_map.items():
        req_val = reqs.get(req_key)
        if req_val not in ("true", "false"):
            print(f"FAIL: requirement {req_key} must be exactly 'true' or 'false', got '{req_val}'")
            return False
            
        req = (req_val == "true")
        res = results.get(lane, "empty")
        
        if req:
            if res != "success":
                print(f"FAIL: {lane} was REQUIRED but resulted in '{res}'")
                all_passed = False
        else:
            if res != "skipped":
                print(f"FAIL: {lane} was NOT required but resulted in '{res}' (expected 'skipped')")
                all_passed = False
                
    if all_passed:
        print("PASS: all lanes matched requirements")
    return all_passed

def main():
    parser = argparse.ArgumentParser(description="CI Policy Script")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    c_parser = subparsers.add_parser("classify")
    c_parser.add_argument("--event", required=True, help="GitHub event name (push, pull_request, workflow_dispatch)")
    c_parser.add_argument("--target-branch", required=False, default="", help="Target branch for the event")
    c_parser.add_argument("--files-json", required=False, default="", help="JSON array of changed files")
    
    g_parser = subparsers.add_parser("gate")
    g_parser.add_argument("--classifier-status", required=True, help="Result of the classifier job")
    g_parser.add_argument("--requirements-json", required=True, help="JSON dict of classifier outputs (needs_*)")
    g_parser.add_argument("--results-json", required=True, help="JSON dict of downstream job results")
    
    args = parser.parse_args()
    
    if args.command == "classify":
        outputs = classify(args)
        for k, v in outputs.items():
            print(f"{k}={v}")
            # Write to GitHub Output if GITHUB_OUTPUT is set
            gh_out = os.environ.get("GITHUB_OUTPUT")
            if gh_out:
                with open(gh_out, "a") as f:
                    f.write(f"{k}={v}\n")
    elif args.command == "gate":
        if not gate(args):
            sys.exit(1)
        sys.exit(0)

if __name__ == "__main__":
    main()
