# AI Companion — Mobile Local Model & Speech Benchmark Evidence

> **Document Role:** Sanitized research evidence for Mobile local AI feasibility, capability qualification, and later architecture/planning promotion.
>
> **Status:** RESEARCH EVIDENCE — NON-CANONICAL
>
> **Intended repository path:** `docs/00_Drafts/research/mobile/benchmarks/MOBILE_LOCAL_MODEL_BENCHMARK_EVIDENCE.md`
>
> **Scope:** Consolidates previously reported Mobile benchmark measurements and qualitative observations into one AI-agent-readable record. Raw screenshots are intentionally unnecessary for this artifact unless later needed for audit.
>
> **Privacy:** The retail phone model and personal/device-identifying details are intentionally omitted. The device is referred to only as **Reference Android Device A**.
>
> **Critical interpretation rule:** These results are feasibility evidence from one reference device and a small number of exploratory runs. They are **not** universal Android guarantees, release thresholds, permanent model choices, or proof of a specific acceleration backend.

---

## 1. Reference Device and Test Environment

### Reference Android Device A

| Field | Recorded value |
|---|---|
| OS | Android 13 |
| CPU / SoC class | MediaTek Dimensity 920-class ARM64 mobile platform |
| Physical RAM | 8 GB |
| Storage | 256 GB class |
| RAM expansion | Not counted as physical RAM |
| Benchmark / chat harness | PocketPal |
| Runtime family | llama.cpp-class local inference |
| Device role | Mobile feasibility reference device only |

### Recorded benchmark-harness configuration

An earlier controlled PocketPal harness run used approximately:

| Setting | Recorded value |
|---|---|
| PocketPal version | 1.17.3 |
| llama.cpp build/version | 10829 |
| Prompt processing tokens | 512 |
| Text generation tokens | 128 |
| Repetitions | 3 |
| Context | 2048 |
| CPU threads | 4 |
| Requested GPU layers | 99 |
| Flash Attention | Off |

**Important:** Requested GPU layers do **not** prove that execution actually used GPU acceleration. The actual backend used by PocketPal was not independently verified. CPU/GPU/NPU attribution therefore remains **UNVERIFIED**.

---

## 2. Evidence Labels

Use these labels when interpreting the tables below:

- **MEASURED:** Numeric value was reported from a benchmark or run.
- **OBSERVED:** Human-observed qualitative result during testing.
- **RECOVERED:** Value was reconstructed from prior benchmark notes/chat logs and should be preserved as research evidence.
- **UNVERIFIED:** The test did not independently prove the underlying implementation detail.
- **NOT TESTED:** No usable evidence was recorded.

---

# 3. Throughput Baseline — Controlled PocketPal Harness

These results came from the earlier PocketPal throughput harness and should be treated as a baseline feasibility snapshot.

| Model | Quantization | Prompt processing | Generation | Memory | UI / responsiveness | Evidence note |
|---|---|---:|---:|---:|---|---|
| Gemma 3 270M | Q8 / Q8_0 class | **172.79 t/s** | **25.56 t/s** | ~754 MB recorded in the earlier harness notes | Good / responsive | Fastest baseline result; quality must be evaluated separately |
| Qwen 3.5 0.8B | Q4-class | **62.49 t/s** | **14.81 t/s** | Not reliably recorded in this baseline | Some lag in exploratory use | Throughput baseline only; later VLM-specific runs are listed separately |
| Qwen 3 0.6B | Q8-class | **52.31 t/s** | **11.75 t/s** | Not reliably recorded in this baseline | Very laggy in one exploratory run | Different quantization/configuration from later Qwen 3 Thinking Q4 run |
| Llama 3.2 1B | Q4-class | **42.87 t/s** | **12.37 t/s** | Not reliably recorded | Noticeable UI/framerate degradation | Feasible, but poorer responsiveness on this device |

### Baseline interpretation

- Sub-1B and ~1B local models were demonstrably capable of interactive generation on the reference device.
- Throughput alone did **not** predict usefulness as a Companion model.
- The fastest small model was not necessarily the best at instruction following, reasoning, multilingual use, or safe tool behavior.
- Backend acceleration remained unverified, so these results must not be labeled “GPU benchmark” or “NPU benchmark.”

---

# 4. Interactive / Capability-Oriented Trials

This section captures follow-up trials that evaluated not only speed, but also practical Companion behavior such as instruction following, task extraction, scheduling, multilingual responses, UI impact, thermal feel, and multimodal capability.

---

## 4.1 Gemma 3 270M Q8

| Field | Evidence |
|---|---|
| Approx artifact size | ~292 MB |
| Context used | 2048 |
| Normal-chat generation | ~20.29–37.77 t/s observed across runs |
| TTFT | ~139–306 ms observed |
| UI hitch | 0 observed |
| Thermal | Cool |
| Battery observation | ~100% → 98% during the recorded trial window |
| Vision | Not tested |
| Tagalog / Taglish | Not completed in the recorded follow-up |
| Instruction following | Weak |
| Reasoning | Weak |
| Task extraction | Weak/inconsistent |
| Reminder intent | Basic reminder time/action could be correct |
| Overall qualitative result | Extremely fast and light, but quality too weak for reliable higher-level Companion reasoning |

### Notes

Gemma 3 270M demonstrated that a very small model can feel extremely responsive on the reference phone. However, speed did not compensate for weak reasoning and instruction-following quality. It is useful as a lower-bound feasibility reference, not the current leading Companion candidate.

---

## 4.2 Qwen 2.5 Instruct 0.5B Q4_K_M

| Field | Evidence |
|---|---|
| Approx artifact size | ~398 MB |
| Context used | 2048 |
| Prompt processing | **51.67 t/s** |
| Generation | **20.98 t/s** |
| Approx peak/displayed memory | ~1 GB class |
| UI hitch | 0 observed |
| Load / responsiveness | Fast / smooth |
| Thermal | Warm |
| Battery observation | ~97% → 93% during the recorded trial window |
| Vision | No |
| Tagalog / code-switching | Poor / insufficient understanding |
| Task extraction | Could separate multiple tasks, but at least one test altered meaning |
| Reminder intent | Basic reminder intent could be recognized |
| Higher-level scheduling/reasoning | Unreliable |
| Overall qualitative result | Capable for its size and smooth on-device, but reasoning and multilingual reliability were not strong enough |

### Notes

This model looked promising on pure speed and basic extraction, but its practical usefulness was limited by unreliable higher-level reasoning and weak Tagalog/code-switch performance.

---

## 4.3 Qwen 3 Thinking 0.6B Q4_K_M

| Field | Evidence |
|---|---|
| Approx artifact size | ~398 MB |
| Context used | 4096 |
| Prompt processing | **53.26 t/s** |
| Generation | **15.09 t/s** |
| Approx memory | ~1 GB class |
| UI hitch | ~1 hitch observed |
| Load time | ~4 seconds observed |
| Thermal | Warm to hot; described as “feels like gaming” during sustained thinking |
| Battery observation | ~89% → 80% during the recorded test sequence |
| Vision | No |
| Instruction following | Mostly good |
| Reasoning | Stronger than the smaller non-thinking alternatives |
| Task extraction | Strong in the recorded test |
| Reminder/action reasoning | At least one reminder action was wrong |
| Tagalog / code-switching | Poor; hallucination/repetition observed |
| Context behavior | Thinking could consume a very large share of context; one run exhausted the available context |
| Overall qualitative result | Stronger reasoning, but token-hungry and costly in latency, battery, thermal load, and context budget |

### Notes

This test is important because it showed that “better reasoning” can create a Mobile resource problem even when raw tokens-per-second remain acceptable. Thinking/reasoning budget must therefore be governed separately from simple context size.

---

## 4.4 Qwen 3.5 0.8B Q4_K_M — Vision-Language Trial

| Field | Evidence |
|---|---|
| Approx artifact size | ~522 MB |
| Context used | 4096 |
| Earlier harness prompt processing | **62.49 t/s** |
| Earlier harness generation | **14.81 t/s** |
| Later recorded run prompt processing | ~64.82 t/s |
| Later recorded run generation | ~15.51 t/s |
| Approx memory during richer/VLM trial | ~2 GB class |
| UI hitch | ~1 observed |
| Local vision | **Working on-device** |
| Simple object recognition | Good on a cat-image test |
| Scene/location reasoning | Hallucinated a street/location as Korea in one test |
| Vision TTFT | ~37.8 seconds in one recorded image test |
| Context behavior | Context exhaustion occurred in the richer multimodal session |
| Thermal / battery | Not controlled enough for a release-quality conclusion |
| Overall qualitative result | Strong evidence that local VLM is feasible on the reference phone, but vision reliability and latency are task-dependent and hallucination risk is real |

### Notes

This result is the main empirical reason local still-image Vision can be treated as **Conditional Mobile V1** instead of “impossible until post-V1.”

It does **not** justify claiming that all vision tasks are reliable. Qualification must remain task-family specific.

---

## 4.5 Gemma 3 1B Q4_K_M

| Field | Evidence |
|---|---|
| Approx artifact size | ~806 MB |
| Context used | 4096 |
| Prompt processing | ~32.74 t/s |
| Generation | ~12.94 t/s |
| Approx memory | ~2 GB class |
| UI hitch | 0 observed |
| Load / response | Usable / responsive |
| Thermal | Mild warmth |
| Battery observation | ~60% → 57% during one recorded trial window |
| Vision | No in this tested configuration |
| Tagalog / Taglish | Best observed among the small tested candidates; usable, though not fully qualified |
| Character/persona following | Decent |
| Context continuity | Decent in short tests |
| Basic task extraction | Decent |
| Higher-level scheduling | Still weak/inconsistent |
| Tool safety behavior | In one test it falsely claimed a reminder had been set even though no actual tool execution occurred |
| Overall qualitative result | Best overall small-model Companion candidate from the recorded trials, but still requires deterministic tool gating and scheduling validation |

### Notes

Gemma 3 1B Q4_K_M currently stands out as the **leading research candidate**, not a locked architecture dependency.

The false “reminder set” claim is especially important. It reinforces the existing architecture rule:

```text
Model proposes intent
→ typed request
→ deterministic policy
→ adapter executes
→ confirmed result
→ only then report success
```

---

# 5. Additional Model Notes

## Llama 3.2 1B Q4-class

Recorded baseline:

- Prompt processing: ~42.87 t/s
- Generation: ~12.37 t/s
- Noticeable UI/framerate degradation on the reference phone
- Tagalog quality was weaker than the strongest tested candidate in later exploratory use
- No complete controlled Companion qualification suite was recorded

Treat this as useful baseline evidence, not a preferred candidate.

## Qwen 3 0.6B Q8-class

Recorded earlier harness:

- Prompt processing: ~52.31 t/s
- Generation: ~11.75 t/s
- Very laggy in one exploratory run
- This result is **not the same configuration** as the later Qwen 3 Thinking 0.6B Q4_K_M test

Do not merge these two Qwen 3 records into one model result.

---

# 6. Practical Capability Comparison

| Capability | Gemma 270M | Qwen 2.5 0.5B | Qwen 3 Thinking 0.6B | Qwen 3.5 0.8B VLM | Gemma 3 1B |
|---|---|---|---|---|---|
| Raw speed | Excellent | Very good | Good | Good | Good enough |
| UI smoothness | Excellent | Excellent | Acceptable | Acceptable | Excellent |
| Resource cost | Very low | Low | Moderate/high for thinking | Moderate/high for VLM | Moderate |
| Instruction following | Weak | Mixed | Good | Mixed / task-dependent | Good enough |
| General reasoning | Weak | Mixed | Better | Mixed | Better than tiny baseline |
| Basic task extraction | Weak/mixed | Decent but unreliable | Strong in one test | Not primary test focus | Decent |
| Higher-level scheduling | Weak | Unreliable | Still error-prone | Not primary test focus | Still weak |
| Tagalog / Taglish | Not completed | Poor | Poor | Not fully qualified | Best observed / usable |
| Vision | No | No | No | **Yes, conditional** | No in tested config |
| Tool-truthfulness | Not qualified | Not qualified | Not qualified | Not qualified | Failed one truthfulness case by claiming reminder success without execution |
| Current research role | Lower-bound speed reference | Lightweight candidate | Reasoning experiment | Local VLM feasibility evidence | Leading small Companion candidate |

---

# 7. TTS Evidence

## KittenTTS

Recorded qualitative observation:

- Approx response/start latency felt around **2–3 seconds**
- Faster/lighter than Kokoro in the Mobile trial
- Voice quality felt more robotic
- Treated as a lightweight Mobile candidate, **not** a permanent engine requirement

Older notes also placed it in a substantially smaller model/runtime-memory class than Kokoro, but those memory figures were not revalidated in the later controlled pass and should not be treated as release measurements.

## Kokoro

Recorded qualitative observation:

- Approx response/start latency felt around **3–5 seconds**
- Slower than Kitten on the tested phone
- More natural voice quality
- Stronger fit for richer speech quality, but heavier
- Remains a provider candidate, not a permanent Mobile requirement

## TTS interpretation

TTS provider choice should remain independent from:

- local LLM
- STT
- Host reachability
- Cloud LLM
- Character identity

Mobile should support provider qualification rather than hardcoding one engine forever.

---

# 8. STT Status

**Mobile STT was NOT benchmarked in the completed evidence set.**

Therefore:

- No Mobile STT engine is qualified yet.
- `whisper.cpp` is the first planned candidate because it aligns with the existing PC Voice architecture.
- Mobile qualification must be independent from PC qualification.

Required future STT tests:

- English
- Tagalog / Filipino
- Taglish / code-switching
- dates and times
- numbers
- noisy environments
- latency
- memory
- battery
- thermal behavior
- barge-in interaction

Until these are measured, local STT must remain **Conditional V1 / unqualified**.

---

# 9. Backend / Acceleration Status

The benchmark environment allowed settings such as requested GPU layers, but the evidence does **not** independently prove which backend executed each workload.

Therefore:

```text
Requested backend / GPU layers
≠
Verified actual backend
```

Current evidence supports:

- local inference feasibility
- approximate throughput
- relative model behavior on one device

Current evidence does **not** prove:

- GPU acceleration
- NPU acceleration
- CPU-only execution
- vendor-specific backend superiority

Future benchmark records should expose both:

- requested backend
- actual backend reported/verified by runtime

---

# 10. What the Evidence Supports Architecturally

These observations support the following architecture directions without locking any specific model:

1. **A production-capable Mobile local LLM path is technically feasible on qualified Android devices.**
2. **The core Mobile app must still function without local generative AI.**
3. **Raw model speed is not a sufficient qualification criterion.**
4. **Reasoning budget must be separately governed because thinking models can consume context, battery, and thermal headroom rapidly.**
5. **Local still-image VLM is feasible on qualified hardware, but must be task-family qualified because hallucination risk is significant.**
6. **Tool actions must remain deterministic and adapter-confirmed because small models may falsely claim successful execution.**
7. **Speech components must remain independently replaceable and independently qualified.**
8. **Device qualification should be evidence-driven rather than tied to a permanent retail phone model, chipset brand, or one model family.**

---

# 11. What the Evidence Does NOT Support

Do **not** infer any of the following from this document:

- that Gemma 3 1B is the permanent Mobile model
- that Qwen 3.5 is the permanent Mobile VLM
- that every 8 GB Android device will behave the same
- that 4 GB devices are unsupported
- that the requested GPU layer count proves GPU execution
- that any benchmark number is a contractual performance guarantee
- that Local STT is already qualified
- that Tagalog/Japanese/code-switching is fully qualified
- that local scheduling can bypass the deterministic scheduling/tool architecture
- that screenshots are required to reproduce the architectural conclusions

---

# 12. Evidence Gaps / Next Qualification Work

Before a release-quality Mobile model qualification is considered complete, add controlled tests for:

### Runtime / performance
- cold-start load time
- warm-load time
- TTFT
- sustained generation for >10 minutes
- exact peak RSS / native heap / total app memory
- UI frame/jank metrics
- process-death recovery
- context scaling at 2K / 4K / larger supported windows
- verified actual backend

### Thermal / battery
- controlled starting battery %
- test duration
- screen brightness/state
- ambient conditions where practical
- battery drop per workload
- thermal status over time
- throttle point / recovery behavior

### Language / Companion quality
- English
- Filipino / Tagalog
- Taglish/code-switching
- Japanese
- future Cebuano/Bisaya, Korean, Russian, etc. only after qualification

### Structured behavior
- Task extraction
- Reminder extraction
- Alarm extraction
- temporal ambiguity
- recurrence
- tool JSON / structured intent
- refusal to claim tool success before adapter confirmation
- conversation compaction / summarization
- Character/personality adherence
- context continuity

### Vision
- object identification
- OCR
- fine-detail description
- spatial reasoning
- scene reasoning
- hallucination resistance
- latency by image size
- context pressure during multimodal sessions

### Speech
- local STT benchmark
- TTS first-audio latency
- TTS real-time factor
- language coverage
- memory
- thermal
- battery
- barge-in behavior

---

# 13. Recommended Qualification Record Shape

Future runs should be logged in a consistent record:

```text
timestamp
device_class
os_version
physical_ram
model_name
model_artifact_hash
parameter_class
quantization
artifact_size
runtime_name
runtime_version
requested_backend
verified_backend
context_size
prompt_tokens
generation_tokens
threads
prompt_tps
generation_tps
ttft
peak_memory
ui_jank
thermal_start
thermal_peak
battery_start
battery_end
duration
language_tests
task_tests
tool_tests
vision_tests
notes
```

This makes later model replacement possible without changing architecture.

---

# 14. Research Conclusion

The current evidence is strong enough to justify a **capability-qualified Mobile local AI architecture**.

The most important finding is not that one particular model “won.” It is that different models trade off:

- speed
- quality
- language ability
- reasoning
- context use
- thermal/battery cost
- vision capability
- tool reliability

in materially different ways on the same phone.

That supports the architectural decision to keep:

- model
- runtime
- backend
- hardware
- capability qualification
- resource governance

as separate concepts.

For the current research set:

- **Gemma 3 270M Q8** is the strongest lower-bound speed/lightweight reference.
- **Qwen 3 Thinking 0.6B Q4_K_M** demonstrates stronger reasoning but excessive thinking/resource cost.
- **Qwen 3.5 0.8B Q4_K_M VL** proves local still-image VLM feasibility but also demonstrates hallucination and latency risk.
- **Gemma 3 1B Q4_K_M** is the current leading small-model Companion candidate because it offered the best observed balance of usability, Tagalog/Taglish behavior, responsiveness, and general Companion quality.
- **No candidate is canonically locked.**

Future release qualification must be based on repeatable evidence, not model reputation or one screenshot.
