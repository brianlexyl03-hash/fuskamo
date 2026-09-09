/**
 * Versioned prompt templates. Bump the version string whenever wording
 * changes meaningfully — token usage logs record which version produced
 * each response, so you can compare quality/cost across versions instead
 * of prompt changes being invisible history.
 */
module.exports = {
  playerSummary: {
    version: 'v1',
    build: ({ name, position, age, country, club, strengths }) =>
      `Write a 2-sentence, neutral scouting note for this player submission. ` +
      `Do not invent facts not given. Name: ${name}. Position: ${position}. Age: ${age}. ` +
      `Country: ${country}. Club: ${club || 'none listed'}. Stated strengths: ${strengths || 'none listed'}.`,
  },
};
