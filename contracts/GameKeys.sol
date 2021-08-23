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
    
    mapping(uint256 => uint256) private _gamePrice; //price by id
    mapping(address => uint256) private _creatorBalances; //game creator balances
    mapping(uint256 => Games) private _gameInfos; //game struct by id
    mapping(uint256 => address) private _gameCreator; 
    //mapping(bytes32 => uint256) private _gameHash;
    mapping(uint256 => bool) private _gameRegistered;

    //todo events

    constructor() ERC721("GameKeys", "GMK") {}
    
    // Functions

    function registerNewGame(Games memory nft, uint256 price_)  public returns (uint256) {
        //require(_gameHash[nft.gameHash] == 0, "GameKeys: This Game already exists");
        _gameIds.increment();
        uint256 newGameId = _gameIds.current();
        _gameCreator[newGameId] = msg.sender;
        _gamePrice[newGameId] = price_;
        _gameInfos[newGameId] = nft;
        _gameRegistered[newGameId] = true;
        return newGameId;
        //todo emit
    }

    function buyGame(uint256 id) public payable {
        //todo require _exists(id)
        require(msg.value >= getPrice(id), "GameKeys: Sorry not enought ethers" );
        _licenseIds.increment();
        uint256 amount = msg.value;
        _creatorBalances[_gameCreator[id]] += amount;
        uint256 newLicenseId = _licenseIds.current();
        _mint(msg.sender, newLicenseId);
        //todo emit
    }

    //todo modifier(onlyCreator)/access control
    function withdraw() public {
        uint256 amount = _creatorBalances[msg.sender];
        _creatorBalances[msg.sender] = 0;
        payable(msg.sender).sendValue(amount);
        //todo emit
    }
    
    // Getters

    function getCreator(uint256 id) public view returns (address) {
        return (_gameCreator[id]);
    }
    
    function getCreatorBalance(address creator) public view returns (uint256) {
        return (_creatorBalances[creator]);
    }
    
    /*function getGameInfos(uint256 id) public view returns (storage) {
        return (_gameInfos[id]);
    }*/
    
    function getPrice(uint256 id) public view returns (uint256) {
        return (_gamePrice[id]);
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

