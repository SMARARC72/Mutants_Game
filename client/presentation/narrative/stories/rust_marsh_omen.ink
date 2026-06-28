// Rust Marsh Omen — the sample vertical's Ink lore branch (Cluster 3, ADR-017).
// Ink DECIDES the branch (reading a real run-state query via an EXTERNAL function)
// and DRIVES state by flipping quest-driver variables that the InkBridge observes.
// It computes NO gameplay numbers — it only gates/triggers. Dialogic renders the
// funny-grim encounter; QuestService writes the actual run state.

// Read-only game queries bound by InkBridge._bind_queries():
EXTERNAL has_creature(id)
EXTERNAL corruption()
EXTERNAL region_unlocked(id)

// Quest-driver variables observed by InkBridge._on_quest_var_changed():
//   flip *_start true   -> QuestService.start(...)
//   set  *_advance str  -> QuestService.advance(..., step)
//   flip *_complete true-> QuestService.complete(...)
VAR quest_rust_marsh_omen_start = false
VAR quest_rust_marsh_omen_advance = ""

// A hint to the orchestrator about which Dialogic timeline to render next.
VAR render_timeline = ""

-> marsh_edge

=== marsh_edge ===
The marsh exhales. Iron-smelling fog, and something underneath it counting your teeth.
{ region_unlocked("rust_marsh"):
    You have stood here before. The fog remembers, which is worse.
- else:
    The bog has not been formally introduced to you. It introduces itself anyway.
}
* [Kneel and read the rust-omens] -> read_omens
* [Leave. You have standards. (You do not.)] -> walk_away

=== read_omens ===
~ quest_rust_marsh_omen_start = true
The omens spell a name in oxidation. It is, rudely, almost your own.
{ has_creature("bog_wretch"):
    Your bog-wretch hums along, delighted to be referenced.
- else:
    Something out in the reeds would very much like to be caught. Take the hint.
}
~ render_timeline = "marsh_encounter"
// Hand control to Dialogic for the authored VN beat, then the quest advances.
-> DONE

=== walk_away ===
You leave. The marsh files a complaint. Corruption noted: { corruption() }.
-> DONE
