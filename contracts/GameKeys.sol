// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract GameKeys is ERC721Enumerable, ERC721URIStorage {
    using Counters for Counters.Counter;
    using Address for address payable;
    
    Counters.Counter private _gameIds;
    Counters.Counter private _licenseIds;
    
        struct Games {
        //bytes32 gameHash;
        string title;
        string cover;
        string creator;
        string description;
        uint256 price;
        address owner;
        string timeStamp;
    }
    
    uint256 private _rate; 
    
    mapping(uint256 => uint256) private _gamePrice; //price by id
    mapping(address => uint256) private _creatorBalances; //game creator balances
    mapping(uint256 => Games) private _gameInfos; //game struct by id
    mapping(uint256 => address) private _gameCreator; 
    //mapping(bytes32 => uint256) private _gameHash;
    mapping(uint256 => bool) private _isGameRegistered;

    // Events
    event GameBenefitsWithdrew(address indexed creator, uint256 profitAmount);
    event GameBought(address indexed buyer, uint256 gameId, uint256 newLicenseId, uint256 price);
    event NewGameRegistered(address indexed creator, uint256 newGameId, uint256 priceInFinney);
    
    // modifier 


    constructor() ERC721("GameKeys", "GMK") {
        _rate = 1e15;
    }
    
    // Functions

    function registerNewGame(Games memory nft, uint256 price_)  public returns (bool) {
        //require(_gameHash[nft.gameHash] == 0, "GameKeys: This Game already exists");
        _gameIds.increment();
        uint256 newGameId = _gameIds.current();
        _gameCreator[newGameId] = msg.sender;
        uint256 priceInFinney = price_ * _rate;
        _gamePrice[newGameId] = priceInFinney;
        _gameInfos[newGameId] = nft;
        emit NewGameRegistered(msg.sender, newGameId, priceInFinney);
        return _isGameRegistered[newGameId] = true;
    }

    function buyGame(uint256 gameId) public payable {
        require(_isGameRegistered[gameId] == true, "GameKeys: Sorryy this game does not exists");
        require(msg.value >= getPrice(gameId), "GameKeys: Sorry not enought ethers" );
        _licenseIds.increment();
        uint256 price = msg.value;
        _creatorBalances[_gameCreator[gameId]] += price;
        uint256 newLicenseId = _licenseIds.current();
        _mint(msg.sender, newLicenseId);
        emit GameBought(msg.sender, gameId, newLicenseId, price);
    }

    //todo modifier(onlyCreator)/access control
    function withdraw(uint256 gameId) public {
        require (msg.sender == _gameCreator[gameId], "GameKeys: Sorry only the game creator can withdraw this balance");
        uint256 profitAmount = _creatorBalances[msg.sender];
        _creatorBalances[msg.sender] = 0;
        payable(msg.sender).sendValue(profitAmount);
        emit GameBenefitsWithdrew(msg.sender, profitAmount);
    }
    
    // Getters

    function getCreator(uint256 gameId) public view returns (address) {
        return (_gameCreator[gameId]);
    }
    
    function getCreatorBalance(address creator) public view returns (uint256) {
        return (_creatorBalances[creator]);
    }
    
    function isGameRegisteredById(uint256 gameId) public view returns (bool) {
        return (_isGameRegistered[gameId]);
    }
    
    function getPrice(uint256 gameId) public view returns (uint256) {
        return (_gamePrice[gameId]);
    }
    
    // Override

    function tokenURI(uint256 tokenId) public view virtual override(ERC721URIStorage, ERC721) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view virtual override(ERC721) returns (string memory) {
        return "https://www.blabla.com";
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC721) returns (bool) {
    return super.supportsInterface(interfaceId);
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)  internal virtual override(ERC721Enumerable, ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721URIStorage, ERC721) {
        super._burn(tokenId);
    }
}
