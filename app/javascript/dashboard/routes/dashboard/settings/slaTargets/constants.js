export const SLA_PRIORITIES = ['low', 'medium', 'high', 'urgent'];

export const SECONDS_PER_UNIT = { minutes: 60, hours: 3600 };

// Shows a whole number of hours in hours, anything else in minutes
export const toDuration = seconds => {
  if (!seconds) return { value: '', unit: 'minutes' };
  if (seconds % SECONDS_PER_UNIT.hours === 0) {
    return { value: seconds / SECONDS_PER_UNIT.hours, unit: 'hours' };
  }
  return {
    value: Math.round(seconds / SECONDS_PER_UNIT.minutes),
    unit: 'minutes',
  };
};

export const toSeconds = ({ value, unit }) =>
  Number(value) > 0 ? Math.round(Number(value) * SECONDS_PER_UNIT[unit]) : null;
