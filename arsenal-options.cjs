const bool = (id, enabled, prefix = 'stratagem_option_') => ({id, prefix, values: [enabled, !enabled]});
const bulk = id => ({id, prefix: 'stratagem_option_', values: ['individual', true, false]});

function definitions(filters) {
  // Preserve existing option positions; append bulk controls after the individual calls.
  return [
    bool('enabled', true, 'autoreload_setting_'),
    bool('charge90', true, 'autoreload_setting_'),
    bool('radial', true), bool('hotkeys', true), bool('shared_other', false),
    {id: 'scale', prefix: 'stratagem_option_', values: [1, 1.5, 2, 3, 4]},
    bool('slow', false),
    ...filters.map(filter => bool(filter.id, false)),
    bulk('shared_all'), bulk('mission_all'), bulk('shared_mission_all')
  ];
}
function suffix(value) {
  if (typeof value === 'boolean') return value ? 'on' : 'off';
  return typeof value === 'number' ? String(value * 100) : value;
}
function label(value, text) {
  if (value === 'individual') return text.Individual;
  return typeof value === 'number' ? `${value * 100}%` : value ? 'ON' : 'OFF';
}
function description(value, text) {
  if (value === 'individual') return text.IndividualDescription;
  if (typeof value === 'number') return text.ScaleDescription.replace('{percent}', value * 100);
  return value ? text.Enabled : text.Disabled;
}
module.exports = {definitions, suffix, label, description};
