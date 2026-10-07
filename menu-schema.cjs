const optionModel = require('./arsenal-options.cjs');
const sourceTranslations = require('./menu-locales.json');
const translations = Object.fromEntries(Object.entries(sourceTranslations).map(([language, locale]) => {
  if (!locale.extends) return [language, locale];
  const base = sourceTranslations[locale.extends];
  if (!base || base.extends) throw new Error(`Invalid base locale: ${language}`);
  return [language, {...base, ...locale, Categories: {...base.Categories, ...locale.Categories},
    Groups: {...base.Groups, ...locale.Groups}, Options: {...base.Options, ...locale.Options},
    Calls: {...base.Calls, ...locale.Calls}}];
}));
const languages = ['en', 'ko', ...Object.keys(translations)];

function schema(filters, texts) {
  const definitions = optionModel.definitions(filters);
  const counts = {};
  const entries = definitions.map(definition => {
    const key = definition.id;
    const category = key.startsWith('mission_') ? 'mission' :
      key.startsWith('shared_') && key !== 'shared_mission_all' ? 'shared' : 'general';
    const filter = filters.find(item => item.id === key);
    counts[category] = (counts[category] || 0) + 1;
    const text = Object.fromEntries(languages.map(language => {
      const translated = translations[language];
      if (translated) {
        const selected = filter ? [translated.Groups[category] + ': ' + translated.Calls[key], translated.FilterDescription] :
          translated.Options[key];
        if (!selected || selected.some(value => typeof value !== 'string') || filter && !translated.Calls[key]) {
          throw new Error(`Incomplete ${language} option translation: ${key}`);
        }
        return [language, {label: selected[0], description: selected[1], mod: translated.Categories[category],
          choices: definition.toggle ? undefined : definition.values.map(value => key === 'slow' ?
            (value ? '30 ms' : '15 ms') : value === 'individual' ? translated.Individual : typeof value === 'number' ?
              `${value * 100}%` : value ? translated.Enabled : translated.Disabled)}];
      }
      const locale = texts[language];
      const selected = filter ? {Name: filter[language], Description: locale.FilterDescription} : locale.Options[key];
      const description = Array.from(selected.Description);
      const mod = language === 'ko' ? {general: 'HD2 헬퍼', shared: 'HD2 헬퍼: 공용', mission: 'HD2 헬퍼: 임무'} :
        {general: 'HD2 Helper', shared: 'HD2 Helper: Common', mission: 'HD2 Helper: Mission'};
      return [language, {label: selected.Name, description: description.length <= 400 ? selected.Description :
        description.slice(0, 397).join('') + '...', mod: mod[category],
        choices: definition.toggle ? undefined : definition.values.map(value => optionModel.label(value, locale, key))}];
    }));
    return {key, id: `hd2_helper.${definition.prefix === 'autoreload_setting_' ? 'autoreload' : 'stratagem'}.${key}`,
      prefix: definition.prefix, toggle: definition.toggle === true, values: definition.values,
      invalid: key === 'scale' ? 1 : false, category: `hd2_helper.${category}`, text,
      gap: key === 'radial' || key === 'shared_mission_all'};
  });
  if (entries.length !== 46 || Object.values(counts).some(count => count > 32)) throw new Error('MODS row budget exceeded');
  return entries;
}

function literal(value) {
  if (typeof value === 'string') {
    return '"' + [...Buffer.from(value)].map(byte => byte === 34 || byte === 92 ? '\\' + String.fromCharCode(byte) :
      byte < 32 || byte >= 127 ? '\\' + String(byte).padStart(3, '0') : String.fromCharCode(byte)).join('') + '"';
  }
  if (typeof value === 'boolean' || typeof value === 'number') return String(value);
  if (Array.isArray(value)) return '{' + value.map(literal).join(',') + '}';
  return '{' + Object.entries(value).filter(([, item]) => item !== undefined)
    .map(([key, item]) => '[' + literal(key) + ']=' + literal(item)).join(',') + '}';
}
module.exports = {schema, literal, languages};
