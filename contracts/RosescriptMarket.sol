pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/draft-IERC1822Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1967Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol"
/*
@openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol
@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol
@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol
@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol
@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol
@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol
@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol
@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol
@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol
@openzeppelin/contracts-upgradeable/utils/StorageSlotUpgradeable.sol
@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol
@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol
@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol
@openzeppelin/contracts/utils/Address.sol
*/
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

struct RRC20Order {
    address seller; // signer of the rrc20 token seller
    address creator; // deployer of the rrc20 token creator
    bytes32 listId;
    string ticker; 
    uint256 amount;
    uint256 price;
    uint256 nonce; // order nonce (must be unique unless new maker order is meant to override existing one e.g., lower ask price)
    uint64 listingTime; // startTime in timestamp
    uint64 expirationTime; // endTime in timestamp
    uint16 creatorFeeRate;
    uint32 salt; // 9-digit
    bytes extraParams; // additional parameters
    uint8 v; // v: parameter (27 or 28)
    bytes32 r; // r: parameter
    bytes32 s; // s: parameter
}

library OrderTypes {
    bytes32 internal constant RRC20_ORDER_HASH =
        keccak256(
            "RRC20Order(address seller,address creator,bytes32 listId,string ticker,uint256 amount,uint256 price,uint256 nonce,uint64 listingTime,uint64 expirationTime,uint16 creatorFeeRate,uint32 salt,bytes extraParams)"
        );

    function hash(RRC20Order memory order) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    RRC20_ORDER_HASH,
                    order.seller,
                    order.creator,
                    order.listId,
                    keccak256(bytes(order.ticker)),
                    order.amount,
                    order.price,
                    order.nonce,
                    order.listingTime,
                    order.expirationTime,
                    order.creatorFeeRate,
                    order.salt,
                    keccak256(order.extraParams)
                )
            );
    }
}

interface IRRC20Market {
    error MsgValueInvalid();
    error ETHTransferFailed();
    error OrderExpired();
    error NoncesInvalid();
    error SignerInvalid();
    error SignatureInvalid();
    error ExpiredSignature();
    error NoOrdersMatched();

   
    event NewTrustedVerifier(address trustedVerifier);
    event AllowBatchOrdersUpdate(bool allowBatchOrders);

    event rosescriptions_protocol_TransferRRC20Token(
        address indexed from,
        address indexed to,
        string indexed ticker,
        uint256 amount
    );

    event rosescriptions_protocol_TransferRRC20TokenForListing(
        address indexed from,
        address indexed to,
        bytes32 id
    );

    event RRC20OrderExecuted(address seller, address taker, bytes32 listId, string ticker, uint256 amount, uint256 price, uint16 feeRate, uint64 timestamp);
    event RRC20OrderCanceled(address seller,bytes32 listId,uint64 timestamp);

    function executeOrder(RRC20Order calldata order, address recipient) external payable;

    function batchMatchOrders(RRC20Order[] calldata orders, address recipient) external payable;

    function cancelOrder(RRC20Order calldata order) external;
    function cancelOrders(RRC20Order[] calldata orders) external;

}



contract RRC20Market is
    IRRC20Market,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using OrderTypes for RRC20Order;

    /// @dev Suggested gas stipend for contract receiving ETH that disallows any storage writes.
    uint256 internal constant _GAS_STIPEND_NO_STORAGE_WRITES = 2300;

    mapping(address => uint256) public userNonces; // unused
    mapping(bytes32 => bool) private cancelledOrFilled;
    address private trustedVerifier;
    bool private allowCancelAll; // unused
    bool private allowBatch;

    function initialize() public initializer {
        __EIP712_init("RRC20Market", "1.0");
        __Ownable_init();
        __ReentrancyGuard_init();

        // default owner
        trustedVerifier = owner();
        allowBatch = false;
    }

    fallback() external {}

    receive() external payable {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function pause() public onlyOwner {
        PausableUpgradeable._pause();
    }

    function unpause() public onlyOwner {
        PausableUpgradeable._unpause();
    }

    function updateTrustedVerifier(address _trustedVerifier) external onlyOwner {
        trustedVerifier = _trustedVerifier;
        emit NewTrustedVerifier(_trustedVerifier);
    }

    function updateAllowBatch(bool _allowBatch) external onlyOwner {
        allowBatch = _allowBatch;
        emit AllowBatchOrdersUpdate(_allowBatch);
    }

    function batchMatchOrders(RRC20Order[] calldata orders, address recipient) public payable nonReentrant whenNotPaused {
        require(allowBatch, "Batch operation is not allowed");
        require(orders.length <= 20, "Too much orders");
        uint16 matched = 0; 
        uint256 userBalance = msg.value;
        for (uint i=0; i<orders.length; i++) {
            RRC20Order calldata order = orders[i];

            // Verify whether order availability
            bytes32 verifyHash = keccak256(abi.encodePacked(order.seller, order.listId));
            if (cancelledOrFilled[verifyHash] || order.nonce != userNonces[order.seller]) {
                // Don't throw error
                continue;
            }

            // Verify the order
            _verifyOrder(order, true);

            
            uint256 orderAmount = order.price * order.amount;
            require(userBalance >= orderAmount, "Insufficient balance");
            userBalance -= orderAmount;

            // Execute the transaction
            _executeOrder(order, recipient, verifyHash, orderAmount);

            matched++;
        }

        if (matched == 0) {
            revert NoOrdersMatched();
        }

        // refund balance
        if (userBalance > 0) {
            _transferETHWithGasLimit(msg.sender, userBalance, _GAS_STIPEND_NO_STORAGE_WRITES);
        }
    }

    function executeOrder(RRC20Order calldata order, address recipient) public payable override nonReentrant whenNotPaused {
        // Check the maker ask order
        bytes32 verifyHash = _verifyOrderHash(order, true);

        // Execute the transaction
        _executeOrder(order, recipient, verifyHash, msg.value);
    }

    function cancelOrder(RRC20Order calldata order) public override nonReentrant whenNotPaused {
        // Check the maker ask order
        bytes32 verifyHash = _verifyOrderHash(order, false);

        // Execute the transaction
        _cancelOrder(order, verifyHash);
    }

    /**
     * @dev Cancel multiple orders
     * @param orders Orders to cancel
     */
    function cancelOrders(RRC20Order[] calldata orders) external override nonReentrant whenNotPaused {
        for (uint8 i = 0; i < orders.length; i++) {
            bytes32 verifyHash = _verifyOrderHash(orders[i], false);
            _cancelOrder(orders[i], verifyHash);
        }
    }

    /**
     * @notice Verify the validity of the rrc20 token order
     * @param order maker rrc20 token order
     */
    function _verifyOrderHash(RRC20Order calldata order, bool verifySeller) internal view returns (bytes32) {



        // Verify whether order availability
        bytes32 verifyHash = keccak256(abi.encodePacked(order.seller, order.listId));
        if (cancelledOrFilled[verifyHash] || order.nonce != userNonces[order.seller]) {
            revert NoncesInvalid();
        }

        _verifyOrder(order, verifySeller);


        return verifyHash;
    }

     /**
     * @notice Verify the validity of the rrc20 token order
     * @param order maker rrc20 token order
     */
    function _verifyOrder(RRC20Order calldata order, bool verifySeller) internal view  {
        // Verify the signer is not address(0)
        if (order.seller == address(0)) {
            revert SignerInvalid();
        }
        // Verify the validity of the signature
        bytes32 orderHash = order.hash();
        address singer = verifySeller ? order.seller : trustedVerifier;
        bool isValid = _verify(
            orderHash,
            singer,
            order.v,
            order.r,
            order.s,
            _domainSeparatorV4()
        );
        
        if (!isValid) {
            revert SignatureInvalid();
        }
    }

    function _executeOrder(RRC20Order calldata order, address recipient, bytes32 verifyHash, uint256 userBalance) internal {
        uint256 toBePaid = order.price * order.amount;
        if (toBePaid != userBalance) {
            revert MsgValueInvalid();
        }

        // Verify the recipient is not address(0)
        require(recipient != address(0), "invalid recipient");

        // Verify whether order has expired
        if ((order.listingTime > block.timestamp) || (order.expirationTime < block.timestamp) ) {
            revert OrderExpired();
        }

        // Update order status to true (prevents replay)
        cancelledOrFilled[verifyHash] = true;

        // Pay eths
        _transferEths(order);

        emit avascriptions_protocol_TransferRRC20TokenForListing(order.seller, recipient, order.listId);

        emit RRC20OrderExecuted(
            order.seller,
            recipient,
            order.listId,
            order.ticker,
            order.amount,
            order.price,
            order.creatorFeeRate,
            uint64(block.timestamp)
        );
    }

    function _cancelOrder(RRC20Order calldata order, bytes32 verifyHash) internal {
        if (order.expirationTime < block.timestamp) {
            revert ExpiredSignature();
        }

        // Update order status to true (prevents replay)
        cancelledOrFilled[verifyHash] = true;

        emit avascriptions_protocol_TransferRRC20TokenForListing(order.seller, order.seller, order.listId);

        emit RRC20OrderCanceled(order.seller, order.listId, uint64(block.timestamp));
    }

    function _transferEths(RRC20Order calldata order) internal {
        uint256 finalSellerAmount = order.price * order.amount;

        // Pay protocol fee
        if (order.creatorFeeRate >= 0) {
            uint256 protocolFeeAmount = finalSellerAmount * order.creatorFeeRate / 10000;
            finalSellerAmount -= protocolFeeAmount;
            if (order.creator != address(this)) {
                _transferETHWithGasLimit(order.creator, protocolFeeAmount, _GAS_STIPEND_NO_STORAGE_WRITES);
            }
        }

        _transferETHWithGasLimit(order.seller, finalSellerAmount, _GAS_STIPEND_NO_STORAGE_WRITES);
    }

    /**
     * @notice It transfers ETH to a recipient with a specified gas limit.
     * @param to Recipient address
     * @param amount Amount to transfer
     * @param gasLimit Gas limit to perform the ETH transfer
     */
    function _transferETHWithGasLimit(address to, uint256 amount, uint256 gasLimit) internal {
        bool success;
        assembly {
            success := call(gasLimit, to, amount, 0, 0, 0, 0)
        }
        if (!success) {
            revert ETHTransferFailed();
        }
    }

    function _verify(bytes32 orderHash, address signer, uint8 v, bytes32 r, bytes32 s, bytes32 domainSeparator) internal pure returns (bool) {
        require(v == 27 || v == 28, "Invalid v parameter");
        // is need Bulk?
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, orderHash));

        address recoveredSigner = ecrecover(digest, v, r, s);
        if (recoveredSigner == address(0)) {
            return false;
        } else {
            return signer == recoveredSigner;
        }
    }

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        Address.sendValue(to, amount);
    }

    function withdrawUnexpectedERC20(address token, address to, uint256 amount) external onlyOwner {
        IERC20Upgradeable(token).safeTransfer(to, amount);
    }


}
