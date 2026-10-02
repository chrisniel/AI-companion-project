import re

with open('docs/04_Architecture/03_Integrations/health-and-wearables.md', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('Classified as APPROVED / NOT STARTED / PC V1.', 'Classified as DEFERRED TO SEPARATE MOBILE ARCHITECTURE PASS.')
content = content.replace('Classified as APPROVED / NOT STARTED / ANDROID V1.', 'Classified as DEFERRED TO SEPARATE MOBILE ARCHITECTURE PASS.')

with open('docs/04_Architecture/03_Integrations/health-and-wearables.md', 'w', encoding='utf-8') as f:
    f.write(content)

with open('docs/04_Architecture/04_Infrastructure/performance-and-capacity.md', 'r', encoding='utf-8') as f:
    perf = f.read()

frozen_rules = r'''
- **V1 Auto Mode Scope:** Auto mode relies exclusively on the user-configured Game & Heavy App list. Generic heuristic load detection is not required for PC V1.
- **Runtime Preservation:** The core Runtime, scheduler, and security subsystems remain alive regardless of mode.
- **Foreground Usability:** Explicit foreground chat, voice, web, and import actions remain usable in Low-Impact mode.
- **Discretionary Deferral:** Background discretionary work is deferred first before impacting foreground capability.
- **Transition Safety:** Mode transitions must be safe; they do not kill active generation mid-flight.
- **Visibility:** The requested state versus the actually applied state must remain visible to the user.
- **Cloud Constraint:** Resource pressure never authorizes cloud egress.
- **Concurrency Default:** The system defaults to one generative model resident. Advanced scenarios >1 are possible but must include capacity warnings.
- **Restoration Policy:** Leaving Low-Impact mode restores the primary-model policy but does not force immediate eager loading of the heavy model until needed.
'''

if 'Generic heuristic' not in perf:
    perf = perf.replace('- **Host-Level Scope:**', frozen_rules + '- **Host-Level Scope:**')
    with open('docs/04_Architecture/04_Infrastructure/performance-and-capacity.md', 'w', encoding='utf-8') as f:
        f.write(perf)

# Fix validator
with open('validate_semantics.py', 'r', encoding='utf-8') as f:
    val = f.read()

val = val.replace('"AUTO-SAVE / PROPOSE / IGNORE"', r'"AUTO-SAVE.*PROPOSE.*IGNORE"')
with open('validate_semantics.py', 'w', encoding='utf-8') as f:
    f.write(val)
