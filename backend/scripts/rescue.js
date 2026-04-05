const { env } = require('process');

async function getContracts() {
  const pubkey = 'GBM6N2SUCK3Y6I5DHQKULZD3W27EYMU37VYHNKWLVBNS6VYZHRJPWJBT';
  const res = await fetch(`https://horizon-testnet.stellar.org/accounts/${pubkey}/operations?limit=50&order=desc`);
  const data = await res.json();
  const creates = data._embedded.records.filter(r => r.type === 'invoke_host_function' && JSON.stringify(r).includes('create_contract'));
  console.log("FOUND DEPLOYS:", creates.length);
  // Extrayendo de las transacciones (Stellar API)
  // Como Horizon a veces no lo parsea directo, podemos usar Stellar SDK, o el tx hash en stellar expert
  console.log(creates.map(c => c.transaction_hash));
}
getContracts();
