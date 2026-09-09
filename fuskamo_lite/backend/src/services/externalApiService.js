const axios = require('axios');

/**
 * Home for third-party API calls that don't deserve their own file yet —
 * e.g. country/region metadata, football data providers, etc. Pattern
 * shown here (a real, working call) is what to copy for the next
 * integration, rather than inventing one with no real API to demo against.
 */
class ExternalApiService {
  /** Example: live list of countries (name + flag) for the submit form's
   *  country field, instead of a hardcoded list drifting out of date. */
  async getCountries() {
    const { data } = await axios.get('https://restcountries.com/v3.1/all?fields=name,flag,cca2');
    return data.map((c) => ({
      name: c.name?.common,
      code: c.cca2,
      flag: c.flag,
    }));
  }
}

module.exports = new ExternalApiService();
