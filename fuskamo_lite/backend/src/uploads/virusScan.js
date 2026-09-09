/**
 * Virus scanning needs a running ClamAV daemon (clamd) — infrastructure
 * this code can't spin up on its own; it has to run alongside the backend
 * (a sidecar container, or a host with clamd installed). Once you have
 * that, this wraps `clamscan` (npm) to scan a buffer before it's accepted:
 *
 *   const NodeClam = require('clamscan');
 *   const clamscan = await new NodeClam().init({ clamdscan: { host: 'clamav', port: 3310 } });
 *   const { isInfected, viruses } = await clamscan.scanBuffer(buffer);
 *
 * Left unimplemented (not faked) until you decide to run a ClamAV
 * container — add it to docker-compose.yml as a `clamav` service and
 * wire the above in here.
 */
async function scanBuffer(buffer) {
  throw new Error('Virus scanning requires a running ClamAV daemon — see uploads/virusScan.js for setup.');
}

module.exports = { scanBuffer };
