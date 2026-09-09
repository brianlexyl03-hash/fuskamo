const crypto=require('node:crypto');
function hashIdentifier(value,salt){if(!value||!salt)throw new Error('value and salt required');return crypto.createHmac('sha256',salt).update(String(value)).digest('hex');}
module.exports={hashIdentifier};
