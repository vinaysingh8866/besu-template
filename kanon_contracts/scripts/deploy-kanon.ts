import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("Deploying Kanon contract...");

  const Kanon = await ethers.getContractFactory("Kanon");
  const kanon = await Kanon.deploy();
  const tx = await kanon.waitForDeployment();
  const kanonAddress = await tx.getAddress();

  const didRegistry = await kanon.didRegistry();
  const schemaRegistry = await kanon.schemaRegistry();
  const credDefRegistry = await kanon.credDefRegistry();
  const revocationRegistry = await kanon.revocationRegistry();

  const deployment = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: Number((await ethers.provider.getNetwork()).chainId),
    deployer: (await ethers.provider.getSigner()).address,
    addresses: {
      Kanon: kanonAddress,
      DIDRegistry: didRegistry,
      SchemaRegistry: schemaRegistry,
      CredentialDefinitionRegistry: credDefRegistry,
      RevocationRegistry: revocationRegistry,
    },
    deployedAt: new Date().toISOString(),
  };

  const outDir = path.join(__dirname, "..", "deployments");
  fs.mkdirSync(outDir, { recursive: true });
  const outFile = path.join(outDir, `${deployment.chainId}.json`);
  fs.writeFileSync(outFile, JSON.stringify(deployment, null, 2));

  console.log("Kanon contract deployed to:", kanonAddress);
  console.log("  DIDRegistry:                 ", didRegistry);
  console.log("  SchemaRegistry:              ", schemaRegistry);
  console.log("  CredentialDefinitionRegistry:", credDefRegistry);
  console.log("  RevocationRegistry:          ", revocationRegistry);
  console.log(`\nDeployment written to: ${outFile}`);
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 