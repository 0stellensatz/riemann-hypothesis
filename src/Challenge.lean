import Mathlib

/-!
# Comparator challenge for the submission's `Main`

This file is not part of the submission. It imports only Mathlib, so these statements are
elaborated without any of the submission's 175,187 files in scope.

`riemannHypothesis` uses Mathlib's own `RiemannHypothesis`. The other four theorems are stated
with definitions copied character for character from the submission's `src/Statements.lean`,
because its `Main` uses them. Comparator requires the solution's definitions to match these, and
`scripts/check-statements.sh` checks that they are identical.

Comparator checks the challenge and solution against the same Mathlib, so the Mathlib pin is
checked separately by `scripts/check-dependencies.sh`. The pin is Mathlib's official `v4.33.1` tag.
-/

def RiemannZetaZerosOnLine : Prop :=
  ∀ s : ℂ, riemannZeta s = 0 → (¬∃ n : ℕ, s = -2 * ((n : ℂ) + 1)) → s ≠ 1 → s.re = 1 / 2

def DirichletLNonvanishingRightOfHalf : Prop :=
  ∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N) (s : ℂ),
    1 / 2 < s.re → (χ ≠ 1 ∨ s ≠ 1) → DirichletCharacter.LFunction χ s ≠ 0

def DirichletLZerosOnLine : Prop :=
  ∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N) (s : ℂ),
    0 < s.re → s.re < 1 → DirichletCharacter.LFunction χ s = 0 → s.re = 1 / 2

def PrimitiveDirichletLZerosOnLine : Prop :=
  ∀ (N : ℕ) [NeZero N] (χ : DirichletCharacter ℂ N), χ.IsPrimitive →
    ∀ s : ℂ, 0 < s.re → s.re < 1 → DirichletCharacter.LFunction χ s = 0 → s.re = 1 / 2

/-- The headline claim, stated with Mathlib's definition only. -/
theorem riemannHypothesis : RiemannHypothesis := by sorry

theorem riemannZeta_eq_zero_re : RiemannZetaZerosOnLine := by sorry

theorem LFunction_ne_zero_of_half_lt_re : DirichletLNonvanishingRightOfHalf := by sorry

theorem LFunction_eq_zero_re : DirichletLZerosOnLine := by sorry

theorem LFunction_eq_zero_re_of_isPrimitive : PrimitiveDirichletLZerosOnLine := by sorry
