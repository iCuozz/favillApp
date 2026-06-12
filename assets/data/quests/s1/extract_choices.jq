.id as $id |
(.pages[].choice // empty) as $choice |
{
  episode_id: $id,
  choice_id: $choice.id,
  prompt: $choice.prompt,
  options: $choice.options | map({
    id: .id,
    label: .label,
    stat_effects: .stat_effects
  })
}
