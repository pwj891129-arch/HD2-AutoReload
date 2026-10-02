const bool = (id, prefix = 'stratagem_option_') => ({id, prefix, values: [true], toggle: true});
const bulk = id => ({id, prefix: 'stratagem_option_', values: ['individual', true, false]});

function definitions(filters) {
  // Preserve existing option positions; append bulk controls after the individual calls.
  return [
    bool('enabled', 'autoreload_setting_'),
    bool('charge90', 'autoreload_setting_'),
    bool('radial'), bool('hotkeys'), bool('shared_other'),
    {id: 'scale', prefix: 'stratagem_option_', values: [1, 1.25, 1.5, 2, 3]},
    {id: 'slow', prefix: 'stratagem_option_', values: [false, true]},
    ...filters.map(filter => bool(filter.id)),
    bulk('shared_all'), bulk('mission_all'), bulk('shared_mission_all')
  ];
}
function suffix(value) {
  if (typeof value === 'boolean') return value ? 'on' : 'off';
  return typeof value === 'number' ? String(value * 100) : value;
}
function label(value, text, id) {
  if (id === 'slow') return value ? '30 ms' : '15 ms';
  if (value === 'individual') return text.Individual;
  return typeof value === 'number' ? `${value * 100}%` : value ? 'ON' : 'OFF';
}
function description(value, text, id) {
  if (id === 'slow') return text.Options.slow.Description;
  if (value === 'individual') return text.IndividualDescription;
  if (typeof value === 'number') return text.ScaleDescription.replace('{percent}', value * 100);
  return value ? text.Enabled : text.Disabled;
}
module.exports = {definitions, suffix, label, description};
