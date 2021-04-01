const PackChain = artifacts.require("PackChain")

function gasLog(k, com){
    return console.log(k.receipt.gasUsed + " gas - " + k.receipt.gasUsed * 20 * 0.000000466792572 + " $ - " + (com ?  com : ""));
}

contract("PackChain", accounts  => {
    var contract;
    var key = "NO_MAN'S_INTERNET";
    
    var client = accounts[0];
    var carrier = accounts[1];

    before(async () => {
        contract = await PackChain.deployed();
    });

    it("Should add users", async () => {
        console.log("USER")
        var t1 = await contract.addUser(0, web3.utils.asciiToHex("PUBLIC_KEY_1"), { from: client });
        gasLog(t1, "Adding a client")
        t1 = await contract.addUser(1, web3.utils.sha3("PRIVATE_KEY_2"), { from: carrier });
        gasLog(t1, "Adding a carrier")
        //t1 = await contract.addUser(0, web3.utils.sha3("PRIVATE_KEY_3"), { from: accounts[2] });
        //gasLog(t1)
        //t1 = await contract.addUser(1, web3.utils.sha3("PRIVATE_KEY_4"), { from: accounts[3] });
        //gasLog(t1)
        //console.log(await contract.getUser(client));
        //console.log(await contract.getUser(carrier));
    })

    it("Should add order", async () => {
        console.log("ORDER")
        var t1 = await contract.addOrder("test", { from: client });
        gasLog(t1, "Making an order")
        //console.log(await contract.getUser(client));
        //console.log(await contract.getOrder(1));
    });

    it("Should add offer", async () => {
        console.log("OFFER")
        var t1 = await contract.addOffer(1, 10, 90, { from: carrier });
        gasLog(t1, "Making an offer")
        //console.log(await contract.getUser(carrier));
        //console.log(await contract.getOrder(1));
        //console.log(await contract.getOffer(1));
    });

    it("Should pay", async () => {
        console.log("PAY")
        var t1 = await contract.pay(1, web3.utils.sha3(key), { from: client, value: 100 });
        gasLog(t1, "Making a payment")
        //console.log(await contract.getOrder(1));
        //console.log(await contract.getOffer(1));
    });

    it("Should deliver", async () => {
        console.log("DELIVER")
        var t1 = await contract.deliver(1, web3.utils.asciiToHex(key), { from: carrier });
        gasLog(t1, "Making a delivery")
        //console.log(await contract.getOrder(1));
        //console.log(await contract.getOffer(1));
        //console.log(await contract.getMyActions({from: client}))
        //console.log(await contract.getMyActions({from: carrier}))
        //console.log(await contract.getOrderActions(1))
    });
});