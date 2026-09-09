const express = require('express');
const router = express.Router();
const { rankCandidates } = require('../ranking/rankingEngine');
const { search } = require('../search/searchEngine');
const { riskScore, decision } = require('../safety/abuseEngine');
const { inspectContent } = require('../safety/contentSafety');
const { assign } = require('../experiments/experimentEngine');
const { rankNotifications } = require('../notifications/notificationRanker');
const { createUploadPlan, videoManifestPlan } = require('../media/mediaPipeline');

router.post('/rank', (req, res) => res.json({ items: rankCandidates(req.body.items, req.body.options) }));
router.post('/search', (req, res) => res.json({ items: search(req.body.query, req.body.items, req.body.options) }));
router.post('/abuse/risk', (req, res) => { const score = riskScore(req.body); res.json({ score, decision: decision(score) }); });
router.post('/safety/content', (req, res) => res.json(inspectContent(req.body)));
router.post('/experiments/assign', (req, res) => res.json({ variant: assign(req.body.experiment, req.body.subjectId) }));
router.post('/notifications/rank', (req, res) => res.json({ items: rankNotifications(req.body.items, req.body.options) }));
router.post('/media/plan', (req, res) => res.json(createUploadPlan(req.body)));
router.post('/media/video-manifest', (req, res) => res.json(videoManifestPlan(req.body)));
module.exports = router;
