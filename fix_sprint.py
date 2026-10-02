import re

with open('docs/02_Planning/00_Master/SPRINT_ROADMAP.md', 'r', encoding='utf-8') as f:
    content = f.read()

new_mobile = r'''### Post-PC-V1: Dedicated Android / Mobile Architecture Pass
- **Primary Objective:** Formally unfreeze and redesign mobile architecture for production Android Companion. The mobile architecture is DEFERRED to a separate architecture pass. Precommitments to Room/outbox, compact mobile LLMs, or Health Connect are removed from this roadmap.

**Preserved Mobile Inputs Only:**
- Package: com.cnl.aicompanion.
- Flutter is the intended production foundation.
- Android development does not block PC V1 delivery.
- One satellite device binds to exactly one Profile.
- Provider/API/device credentials remain device-local.
- Current Kotlin repository code serves strictly as prototype/reference evidence.
- **Exit Criteria:** Approved Mobile System Baseline and Mobile WBS ready for implementation. Does not block PC V1.'''

content = re.sub(r'### Post-PC-V1: Dedicated Android / Mobile Architecture Pass.*?(?=$)', new_mobile, content, flags=re.DOTALL)

with open('docs/02_Planning/00_Master/SPRINT_ROADMAP.md', 'w', encoding='utf-8') as f:
    f.write(content)
