# Initial directional-facing audit

Audited after merging `origin/main` at `70749fe`, before any regeneration in this task.
Direction order is `south, south-east, east, north-east, north, north-west, west, south-west`.

## Failing cells

| Set | Failing cells | Visual reason |
|---|---|---|
| Warrior | east, north-west, west | east/west are frontal rather than opposite profiles; north-west shows the face |
| Archer | east, north-east, north-west, south-west | east is frontal; both northern obliques show the face; south-west is a profile |
| bamboo_brute | north-east, north-west, south-west | northern obliques show red face; south-west shows blank back |
| bamboo_spirit_lord | north-east, north-west | both northern obliques show the white face |
| cheonyeo_gwisin | all eight | five-column raw layout was sliced as four columns, leaving neighboring-cell fragments in every output |
| forest_spirit | north-east, north-west | both northern obliques show the pale face |
| gumiho | south-east, north-east, north, north-west | south-east is a rear view; the three northern cells collapse into an indistinct tail fan |

## Sets left unchanged

Taoist, blue_dokkaebi, bulgasari, dalgyal_gwisin, dokkaebi_fire, dokkaebi_king,
forest_goblin, fox_spirit, gumiho_scout, gwimyeon_dokkaebi, haetae_guardian,
imugi_whelp, jeoseung_saja, seonbi_wraith, shadow_dokkaebi, tomb_jangseung,
wonhon, and ancient_imugi passed manual facing review.

## Second-pass correction

The first pass missed three same-facing profile pairs. A follow-up east/west
mirror diagnostic made them conspicuous before the audit was finalized:

| Set | Additional failing cell | Visual reason |
|---|---|---|
| gumiho | west | identical right-facing profile to east |
| imugi_whelp | west | identical right-facing head and coil to east |
| tomb_jangseung | west | carved face remains on the same side as east |

These three entries supersede their inclusion in “Sets left unchanged” above.
Their correct east cells are reflected into west, which preserves every pixel
of the accepted identity while guaranteeing an opposite profile at zero credit.
