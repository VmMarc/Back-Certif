// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title   GameKeys
 * @author  Victor
 *
 * @notice  In this contract NFTs are game license keys
 * @dev     This contract work this way:
 *          - The Admin add a new game developer
 *          - The Game Dev can register a new game (struct)
 *          - Then the use can buy/mint the NFT game license
 *          - Finally the Game Dev can withdraw his balances
 */
contract GameKeys is ERC721Enumerable, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    using Address for address payable;

    /**
     * @notice  State variables
     * @dev     Game is the struc for the future NFT to be minted
     * */
    struct Game {
        string title;
        string cover;
        address creator;
        string description;
        uint256 price;
        uint256 gameID;
        uint256 date;
        bytes32 gameHash;
    }

    /**
     * @dev    These are the two different roles in this contract
     * (ADMIN_ROLE has power over GAME_CREATOR_ROLE)
     * */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GAME_CREATOR_ROLE = keccak256("GAME_CREATOR_ROLE");

    /// @dev    _rate is the rate in Finney (^15)
    uint256 private _rate;
    //uint256 private _nbGames; add after deleteGame function added
    address private _admin;

    /// @dev    Counter for game IDs which will be incremented inside the function registerNewGame function
    Counters.Counter private _gameIds;
    /// @dev    Counter for license IDs which will be incremented inside the function buyGame function
    Counters.Counter private _licenseIds;

    /// @dev    This mapping check if the game is registered
    mapping(uint256 => bool) private _isGameRegistered;
    /// @dev    Mapping to get the struct from a game ID
    mapping(uint256 => Game) private _gameInfos;
    /// @dev    Mapping to get the game ID from a license ID
    mapping(uint256 => uint256) private _licenseToGame;
    /// @dev    Mapping to get the Game Dev balances
    mapping(address => uint256) private _creatorBalances;
    /// @dev    Mapping to get the Game ID from a hash
    mapping(bytes32 => uint256) private _gameHash;

    /**
     * @dev                 Emitted when a Game Dev withdraw his balances
     * @param creator        Game Dev address
     * @param profitAmount     amount of the balances
     * */
    event GameBenefitsWithdrew(address indexed creator, uint256 profitAmount);

    /**
     * @dev                 Emitted when a user buy a game
     * @param buyer        User address
     * @param gameId     Game ID
     * @param newLicenseId        License ID
     * @param price     game price
     * */
    event GameBought(address indexed buyer, uint256 gameId, uint256 newLicenseId, uint256 price);

    /**
     * @dev                 Emitted when a game is registered
     * @param creator        Game Dev address
     * @param newGameId     Game ID
     * @param priceInFinney        game price
     * */
    event NewGameRegistered(address indexed creator, uint256 newGameId, uint256 priceInFinney);

    /**
     * @dev                 Emitted when the Admin add a new Game Dev
     * @param gameCreator        Game Dev address
     * */
    event GameCreatorAdded(address indexed gameCreator);

    /**
     * @dev                 Emitted when the Admin revoke a Game Dev
     * @param gameCreator        Game Dev address
     * */
    event GameCreatorRevoked(address indexed gameCreator);

    /**
     * @notice  Constructor
     * @dev     The contract is deployed with the admin address
     *          Then we set up the deployer to DEFAULT_ADMIN_ROLE
     *          And we also set up that ADMIN_ROLE has power over GAME_CREATOR_ROLE
     *          Set the right rate in Finney
     * @param   admin_ admin address
     * */
    constructor(address admin_) ERC721("GameKeys", "GMK") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, admin_);
        _setRoleAdmin(GAME_CREATOR_ROLE, ADMIN_ROLE);
        _rate = 1e15;
        _admin = admin_;
    }

    /**
     * @dev     This function allow only for GAME_CREATOR_ROLE to add a new game
     *
     *          Emit a {NewGameRegistered} event
     *
     * @param title      game title
     * @param cover   url of the cover
     * @param description    little pitch for the game
     * @param price    game price
     */
    function registerNewGame(
        string memory title,
        string memory cover,
        string memory description,
        uint256 price
    ) public onlyRole(GAME_CREATOR_ROLE) returns (bool) {
        bytes32 uniqueGameHash = keccak256(abi.encode(title));
        require(_gameHash[uniqueGameHash] == 0, "GameKeys: This Game already exists");
        // todo _nbGames.increment(); add after deleteGame function added
        _gameIds.increment();
        uint256 newGameId = _gameIds.current();
        _gameHash[uniqueGameHash] = newGameId;
        uint256 priceInFinney = price * _rate;
        _gameInfos[newGameId] = Game(
            title,
            cover,
            msg.sender,
            description,
            priceInFinney,
            newGameId,
            block.timestamp,
            uniqueGameHash
        );
        emit NewGameRegistered(msg.sender, newGameId, priceInFinney);
        return _isGameRegistered[newGameId] = true;
    }

    /**
     * @dev     This function allow lambda user to buy and mint a NFT license key from a game ID
     *
     *          Emit a {GameBought} event
     *
     * @param gameId      game ID
     */
    function buyGame(uint256 gameId) public payable {
        require(_isGameRegistered[gameId] == true, "GameKeys: Sorry this game does not exists");
        require(msg.value >= _gameInfos[gameId].price, "GameKeys: Sorry not enought ethers");
        _licenseIds.increment();
        uint256 newLicenseId = _licenseIds.current();
        _licenseToGame[newLicenseId] = gameId;
        uint256 price = msg.value;
        _creatorBalances[_gameInfos[gameId].creator] += price;
        _mint(msg.sender, newLicenseId);
        emit GameBought(msg.sender, gameId, newLicenseId, price);
    }

    /**
     * @dev     This function allow only GAME_CREATOR_ROLE to withdraw his own balances
     *          The pattern check, effect, interaction is respected to prevent reentrancy attack
     *
     *          Emit a {GameBenefitsWithdrew} event
     */
    function withdraw() public onlyRole(GAME_CREATOR_ROLE) {
        require(_creatorBalances[msg.sender] != 0, "GameKeys: Sorry balances are empty, nothing to withdraw");
        uint256 profitAmount = _creatorBalances[msg.sender];
        _creatorBalances[msg.sender] = 0;
        payable(msg.sender).sendValue(profitAmount);
        emit GameBenefitsWithdrew(msg.sender, profitAmount);
    }

    /* todo
    function deleteGame(uint256 gameId) public onlyRole(GAME_CREATOR_ROLE) returns (bool){
        require (_gameInfos[newGameId] != 0, "GameKeys: Game you trying to delete does not exists");
        _nbGames.decrement();
        _gameInfos[newGameId] = 0;
        emit gameDeleted(msg.sender, gameId);
    }
    */

    /**
     * @dev     This function allow only ADMIN_ROLE to add a new GAME_CREATOR_ROLE
     *
     *          Emit a {GameCreatorAdded} event
     */
    function addGameCreator(address account) public onlyRole(ADMIN_ROLE) {
        grantRole(GAME_CREATOR_ROLE, account);
        emit GameCreatorAdded(account);
    }

    /**
     * @dev     This function allow only ADMIN_ROLE to revoke a new GAME_CREATOR_ROLE
     *
     *          Emit a {GameCreatorAdded} event
     */
    function revokeGameCreator(address account) public onlyRole(ADMIN_ROLE) {
        revokeRole(GAME_CREATOR_ROLE, account);
        emit GameCreatorRevoked(account);
    }

    /**
     * @notice  Getter functions
     * @dev     This functions must be overrided to use ERC721Enumerable
     *          These are getters to have access to particular objects inside the Game struct
     *          It goes until lign 252
     * @param   gameId game ID
     */
    function getTitleById(uint256 gameId) public view returns (string memory) {
        return (_gameInfos[gameId].title);
    }

    function getCoverById(uint256 gameId) public view returns (string memory) {
        return (_gameInfos[gameId].cover);
    }

    function getCreator(uint256 gameId) public view returns (address) {
        return (_gameInfos[gameId].creator);
    }

    function getDescriptionById(uint256 gameId) public view returns (string memory) {
        return (_gameInfos[gameId].description);
    }

    function getPrice(uint256 gameId) public view returns (uint256) {
        return (_gameInfos[gameId].price);
    }

    function getTimestampById(uint256 gameId) public view returns (uint256) {
        return (_gameInfos[gameId].date);
    }

    /**
     * @dev     This getter return all the Game struct
     * @param   gameId game ID
     */
    function getGameInfosById(uint256 gameId) public view returns (Game memory) {
        return (_gameInfos[gameId]);
    }

    /**
     * @dev     This getter check if the game ID is registered
     * @param   gameId game ID
     */
    function isGameRegisteredById(uint256 gameId) public view returns (bool) {
        return (_isGameRegistered[gameId]);
    }

    /**
     * @dev     This getter check Game dev balances
     * @param   creator Game Dev address
     */
    function getCreatorBalance(address creator) public view returns (uint256) {
        return (_creatorBalances[creator]);
    }

    /**
     * @dev     This getter return the game ID attached to a license ID
     * @param   licenseId game license ID
     */
    function getGameByLicenceId(uint256 licenseId) public view returns (uint256) {
        return _licenseToGame[licenseId];
    }

    /**
     * @dev     This getter return ADMIN address
     */
    function admin() public view returns (address) {
        return _admin;
    }

    /**
     * @dev     This getter return if an address has ADMIN_ROLE
     * @param   account address to check
     */
    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev     This getter return if an address has GAME_CREATOR_ROLE
     * @param   account address to check
     */
    function isGameCreator(address account) public view returns (bool) {
        return hasRole(GAME_CREATOR_ROLE, account);
    }

    /**
     * @dev     This getter return the current incrementation of _gameIds
     */
    function gameTotalSupply() public view returns (uint256) {
        return _gameIds.current();
    }

    /**
     * @dev     This getter return the current incrementation of _licenseIds
     */
    function licenceTotalSupply() public view returns (uint256) {
        return _licenseIds.current();
    }

    /* todo add after deleteGame function added
    function nbGames() public view returns (uint256) {
        return _nbGames.current();
    }
    */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view virtual override(ERC721) returns (string memory) {
        return "https://www.blabla.com";
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorage, ERC721) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable, ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}
