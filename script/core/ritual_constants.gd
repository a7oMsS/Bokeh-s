extends RefCounted
class_name RitualConstants

## Ritual identity, carried in the payload Dictionary from BaseRitual._finish().
const TYPE_CONDENSE := "condense"
const TYPE_TRACE := "trace"  # reserved, not implemented yet

## Ritual outcome, same payload.
const RESULT_SUCCESS := "success"
const RESULT_CANCEL := "cancel"

## Gesture quality tiers used by ScoreManager.
const TIER_NORMAL := "normal"
const TIER_GOOD := "good"
const TIER_PERFECT := "perfect"

## Audio bus shared by the charge and success voices.
const AUDIO_BUS_CONDENSE := "Condense"
