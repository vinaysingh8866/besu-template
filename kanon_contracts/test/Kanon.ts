import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";

describe("KanonProtocol", function () {
  async function deployKanonFixture() {
    const kanon = await hre.ethers.getContractFactory("Kanon");
    const kanonContract = await kanon.deploy();
    return { kanonContract };
  }

  describe("Deployment", function () {
    it("Should deploy the contract", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      expect(await kanonContract.getAddress()).to.not.be.undefined;
    });
  });

  describe("DIDRegistry", function () {
    it("Should register a DID", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      await kanonContract.registerDID("did:example:123", "context", "metadata");
      expect(
        JSON.stringify(await kanonContract.getDID("did:example:123"))
      ).to.equal(JSON.stringify(["context", "metadata"]));
    });
  });

  describe("SchemaRegistry", function () {
    it("Should register a Schema", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      await kanonContract.registerSchema("schemaId", "details");

      expect(
        JSON.stringify(await kanonContract.getSchema("schemaId"))
      ).to.equal(JSON.stringify(["details", []]));
    });
    it("Should add an approved issuer", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      await kanonContract.addApprovedIssuer(
        "schemaId",
        "0x1234567890123456789012345678901234567890"
      );

      expect(
        JSON.stringify(await kanonContract.getSchema("schemaId"))
      ).to.equal(
        JSON.stringify(["", ["0x1234567890123456789012345678901234567890"]])
      );
    });
  });

  describe("CredentialDefinitionRegistry", function () {
    it("Should register a Credential Definition", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      await kanonContract.registerCredentialDefinition(
        "credDefId",
        "schemaId",
        "0x1234567890123456789012345678901234567890"
      );

      expect(
        JSON.stringify(await kanonContract.getCredentialDefinition("credDefId"))
      ).to.equal(
        JSON.stringify([
          "schemaId",
          "0x1234567890123456789012345678901234567890",
        ])
      );
    });
  });

  describe("RevocationRegistry", function () {
    it("Should revoke a Credential", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);
      await kanonContract.issueCredential(
        "credId",
        "credDefId",
        "issuer",
        "subject",
        "issuanceDate",
        "expiryDate",
        "metadata"
      );
    });

    it("Should fail if the credential is already revoked", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      await kanonContract.issueCredential(
        "credId",
        "credDefId",
        "issuer",
        "subject",
        "issuanceDate",
        "expiryDate",
        "metadata"
      );

      await kanonContract.revokeCredential("credId");

      await expect(kanonContract.revokeCredential("credId")).to.be.revertedWith(
        "Credential is already revoked"
      );
    });

    it("Should fail if the credential does not exist", async function () {
      const { kanonContract } = await loadFixture(deployKanonFixture);

      await expect(kanonContract.revokeCredential("credId")).to.be.revertedWith(
        "Credential does not exist"
      );
    });
  });
});
