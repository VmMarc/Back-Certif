// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameKeys is ERC721Enumerable, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    using Address for address payable;

    struct Game {
        string title;
        string cover;
        address creator;
        string description;
        uint256 price;
        uint256 date;
        bytes32 gameHash;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant GAME_CREATOR_ROLE = keccak256("GAME_CREATOR_ROLE");

    uint256 private _rate;
    //uint256 private _nbGames; add after deleteGame function added
    address private _admin;


    Counters.Counter private _gameIds;
    Counters.Counter private _licenseIds;

    mapping(uint256 => bool) private _isGameRegistered;
    mapping(uint256 => Game) private _gameInfos;
    mapping(uint256 => uint256) private _licenseToGame;
    mapping(address => uint256) private _creatorBalances;
    mapping(bytes32 => uint256) private _gameHash;

    // -----------------Events-----------------
    event GameBenefitsWithdrew(address indexed creator, uint256 gameId, uint256 profitAmount);
    event GameBought(address indexed buyer, uint256 gameId, uint256 newLicenseId, uint256 price);
    event NewGameRegistered(address indexed creator, uint256 newGameId, uint256 priceInFinney);
    event GameCreatorAdded(address indexed gameCreator);
    event GameCreatorRevoked(address indexed gameCreator);

    // -----------------modifier---------------

    constructor(address admin_) ERC721("GameKeys", "GMK") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, admin_);
        _setRoleAdmin(GAME_CREATOR_ROLE, ADMIN_ROLE);
        _rate = 1e15;
        _admin = admin_;
    }

    // -----------------Functions----------------------

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
            block.timestamp,
            uniqueGameHash
        );
        emit NewGameRegistered(msg.sender, newGameId, priceInFinney);
        return _isGameRegistered[newGameId] = true;
    }

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

    function withdraw(uint256 gameId) public onlyRole(GAME_CREATOR_ROLE){
        require(
            msg.sender == _gameInfos[gameId].creator,
            "GameKeys: Sorry only the game creator can withdraw this balance"
        );
        uint256 profitAmount = _creatorBalances[msg.sender];
        _creatorBalances[msg.sender] = 0;
        payable(msg.sender).sendValue(profitAmount);
        emit GameBenefitsWithdrew(msg.sender, gameId, profitAmount);
    }

    /* todo
    function deleteGame(uint256 gameId) public onlyRole(GAME_CREATOR_ROLE) returns (bool){
        require (_gameInfos[newGameId] != 0, "GameKeys: Game you trying to delete does not exists");
        _nbGames.decrement();
        _gameInfos[newGameId] = 0;
        emit gameDeleted(msg.sender, gameId);
    }
    */

    // ----------------------Access Control functions--------------------------

    function addGameCreator(address account) public onlyRole(ADMIN_ROLE) {
        grantRole(GAME_CREATOR_ROLE, account);
        emit GameCreatorAdded(account);
    }

    function revokeGameCreator(address account) public onlyRole(ADMIN_ROLE) {
        revokeRole(GAME_CREATOR_ROLE, account);
        emit GameCreatorRevoked(account);
    }

    // -------------------Getters----------------------

    // Struct Game getter object by object
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
    //End of getters of the struct object by object

    // Try to get all struct ok : 
    function getGameInfosById(uint256 gameId) public view returns (Game memory) {
        return (_gameInfos[gameId]);
    }

    //getter to check of game is registered
    function isGameRegisteredById(uint256 gameId) public view returns (bool) {
        return (_isGameRegistered[gameId]);
    }

    // getter to check the game creator
    function getCreatorBalance(address creator) public view returns (uint256) {
        return (_creatorBalances[creator]);
    }

    //getter to check the game attached to le license
    function getGameByLicenceId(uint256 licenseId) public view returns (uint256) {
        return _licenseToGame[licenseId];
    }

    //getter to check the address attached to the ADMIN_ROLE
    function admin() public view returns (address) {
        return _admin;
    }

    function isAdmin(address account) public view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    function isGameCreator(address account) public view returns (bool) {
        return hasRole(GAME_CREATOR_ROLE, account);
    }

    /* todo add after deleteGame function added
    function nbGames() public view returns (uint256) {
        return _nbGames.current();
    }
    */

    // ------------------------Overrides-------------------------------

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
