// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

contract PackChain {
    address public owner;
    
    mapping(address => User) private users;

    Order[] private orders;
    Offer[] private offers;
    
    constructor() public {
        owner = msg.sender;

        orders.push(Order({
            status: OrderStatusEnum.Done,
            client: msg.sender,
            offerIdw: 0,
            content: ''
        }));

        offers.push(Offer({
            status: OfferStatusEnum.Closed,
            carrier: msg.sender,
            orderId: 0,
            prepay: 0,
            deposit: 0,
            keyHash: 0
        }));
    }

    //////////////////
    // USER
    //////////////////

    enum UserStatusEnum { Client, Carrier }

    struct User {
        UserStatusEnum status;
        bytes32 key;
    }

    modifier isReg() {
        require(users[msg.sender].key != 0);
        _;
    }

    modifier isClient() {
        require(users[msg.sender].key != 0
            && users[msg.sender].status == UserStatusEnum.Client);
        _;
    }

    modifier isCarrier() {
        require(users[msg.sender].key != 0
            && users[msg.sender].status == UserStatusEnum.Carrier);
        _;
    }

    event UserEvent(address indexed user);

    function addUser(
        UserStatusEnum status,
        bytes32 key
    ) public {
        require(users[msg.sender].key == 0);

        users[msg.sender] = User({
            status: status,
            key: key
        });

        emit UserEvent(msg.sender);
    }

/*
    function rateUser(
        uint32 orderId,
        uint16 score,
        address user_rated
    ) public 
      isReg
    {
        require(score > 0 && score <= 1000);
        require(msg.sender != user_rated);

        Order storage order = orders[orderId];
        Offer storage offer = offers[order.offerIdw];

        require(order.offerIdw != 0);
        require(msg.sender == order.client || msg.sender == offer.carrier);
        require(user_rated == order.client || user_rated == offer.carrier);
        require(order.score[user_rated == order.client ? 1 : 0] == 0);

        order.score[user_rated == order.client ? 1 : 0] = score;

        User storage user = users[user_rated];
        uint32 weight = (user.repTotal > 7 ? 7 : user.repTotal);

        user.rep = (user.rep * weight + score) / (weight + 1);
        user.repTotal = user.repTotal + 1;
    }
*/
    function getUser(
        address addr
    ) public view
        isReg
        returns (  
            UserStatusEnum status,
            bytes32 key
        )
    {
        User storage u = users[addr];
        return (u.status, u.key);
    }

    //////////////////
    // ORDER
    //////////////////

    enum OrderStatusEnum { New, Process, Done }
    
    struct Order {
        OrderStatusEnum status;
        address payable client;     // Client eth address
        uint offerIdw;   
        string content;
    }

    event OrderEvent(address indexed user, uint indexed order);

    function addOrder(
        string memory content
    )   public  
        isClient
    {
        orders.push(Order({
            status: OrderStatusEnum.New,
            client: msg.sender,
            offerIdw: 0,
            content: content
        }));

        emit OrderEvent(msg.sender, orders.length - 1);
    }

    function getOrder(
        uint orderId
    ) public view
        isReg
        returns (
            OrderStatusEnum status,
            address client,     // Client eth address
            uint offerIdw,
            string memory content
        )
    {
        User storage user = users[msg.sender];
        Order storage order = orders[orderId];
        
        require(user.status == UserStatusEnum.Carrier || order.client == msg.sender);

        return (
            order.status,
            order.client,     // Client eth address
            order.offerIdw,
            order.content
        );
    }

    //////////////////
    // OFFER
    //////////////////

    enum OfferStatusEnum { New, Settled, Closed, Refund }
    
    struct Offer {
        OfferStatusEnum status;
        
        address payable carrier;    // Carrier eth address 
        
        uint orderId;
        
        uint prepay;                // Advance payment
        uint deposit;               // Deposit to receive after delivery is satisfied
        bytes32 keyHash;            // Hash of the secret key
    }

    event OfferEvent(address indexed user, uint indexed order, uint offer);

    function addOffer(
        uint orderId,
        uint prepay,
        uint deposit
    )   public  
        isCarrier
    {
        offers.push(Offer({
            status: OfferStatusEnum.New,

            carrier: msg.sender,

            orderId: orderId,

            prepay: prepay,
            deposit: deposit,
            keyHash: 0
        }));

        emit OfferEvent(msg.sender, orderId, offers.length - 1);
    }

    function getOffer(
        uint offerId        
    )   public view
        isReg
        returns (
            OfferStatusEnum status,
            address carrier,    // Carrier eth address 
            uint orderId,
            uint prepay,
            uint deposit
        ) 
    {
        Offer storage offer = offers[offerId];
        Order storage order = orders[offer.orderId];

        require(offer.carrier == msg.sender || order.client == msg.sender);

        return (
            offer.status,
            offer.carrier,    // Carrier eth address 
            offer.orderId,
            offer.prepay,
            offer.deposit
        );
    } 

    //////////////////
    // PAY
    //////////////////

    event PaymentEvent(address indexed user, uint offer);

    function pay(
        uint offerId,
        bytes32 keyHash
    )   public payable
        isClient
    {
        Offer storage offer = offers[offerId];
        Order storage order = orders[offer.orderId];

        require(
            order.client == msg.sender
            && order.status == OrderStatusEnum.New
            && offer.status == OfferStatusEnum.New
        );

        uint prepay = offer.prepay;
        uint deposit = offer.deposit;
        uint amount = prepay + deposit;

        require(msg.value == amount);

        order.status = OrderStatusEnum.Process;
        order.offerIdw = offerId;

        offer.status = OfferStatusEnum.Settled;
        offer.keyHash = keyHash;
        
        if (prepay != 0) {
            address caddress = address(this);
            uint preBalance = caddress.balance;

            offer.carrier.transfer(prepay);

            uint postBalance = caddress.balance;
            assert(postBalance == preBalance - prepay);
        }

        emit PaymentEvent(msg.sender, offerId);
    }

    //////////////////
    // DELIVER
    //////////////////

    event DeliverEvent(address indexed user, uint indexed order);

    function deliver(
        uint orderId,
        bytes memory key
    )   public
        isCarrier
    {
        Order storage order = orders[orderId];
        Offer storage offer = offers[order.offerIdw];

        require(offer.carrier == msg.sender 
            && order.status == OrderStatusEnum.Process
            && offer.status == OfferStatusEnum.Settled
            && offer.keyHash == keccak256(key));

        order.status = OrderStatusEnum.Done;
        offer.status = OfferStatusEnum.Closed;

        uint deposit = offer.deposit;

        if (deposit != 0) {
            address caddress = address(this);
            uint balanceBefore = caddress.balance;

            offer.carrier.transfer(deposit);

            uint balanceAfter = caddress.balance;
            assert(balanceAfter == balanceBefore - deposit);
        }

        emit DeliverEvent(msg.sender, orderId);
    }

    //////////////////
    // REFUND
    //////////////////

    event RefundEvent(address indexed user, uint indexed order);

    function refund(
        uint orderId
    )   public
        isCarrier
    {
        Order storage order = orders[orderId];
        Offer storage offer = offers[order.offerIdw];

        require(offer.carrier == msg.sender);
        require(order.status == OrderStatusEnum.Process);
        require(offer.status == OfferStatusEnum.Settled);

        order.status = OrderStatusEnum.Done;
        offer.status = OfferStatusEnum.Refund;

        uint deposit = offer.deposit;

        if (deposit != 0) {
            address caddress = address(this);
            uint balanceBefore = caddress.balance;

            order.client.transfer(deposit);

            uint balanceAfter = caddress.balance;
            assert(balanceAfter == balanceBefore - deposit);
        }

        emit RefundEvent(msg.sender, orderId);
    }
}