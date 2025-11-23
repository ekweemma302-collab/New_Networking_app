import { Clarinet, Tx, Chain, Account, types } from "@hirosystems/clarinet-sdk";

Clarinet.test({
  name: "devices can register and create sessions, guests can deposit liquidity",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const alice = accounts.get("wallet_1")!;
    const bob = accounts.get("wallet_2")!;

    let block = chain.mineBlock([
      Tx.contractCall(
        "networking",
        "register-device",
        [types.buff(Buffer.from("Alice laptop"))],
        alice.address
      ),
      Tx.contractCall(
        "networking",
        "register-device",
        [types.buff(Buffer.from("Bob phone"))],
        bob.address
      )
    ]);

    block.receipts[0].result.expectOk();
    const aliceDeviceId = block.receipts[0].result.expectOk().expectUint();
    const bobDeviceId = block.receipts[1].result.expectOk().expectUint();

    let block2 = chain.mineBlock([
      Tx.contractCall(
        "networking",
        "create-session",
        [types.uint(aliceDeviceId), types.uint(1000000)],
        alice.address
      )
    ]);

    const sessionId = block2.receipts[0].result.expectOk().expectUint();

    let block3 = chain.mineBlock([
      Tx.contractCall(
        "networking",
        "join-and-deposit",
        [types.uint(sessionId), types.uint(bobDeviceId), types.uint(1000000)],
        bob.address
      )
    ]);

    block3.receipts[0].result.expectOk();

    let block4 = chain.mineBlock([
      Tx.contractCall(
        "networking",
        "close-session",
        [types.uint(sessionId), types.principal(bob.address)],
        alice.address
      )
    ]);

    block4.receipts[0].result.expectOk();
  },
});
