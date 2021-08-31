/* eslint-disable quotes */
/* eslint-disable no-undef */
/* eslint-disable no-unused-expressions */

const { expect } = require('chai');

describe('GameKeys', function () {
  let deployer,
    admin,
    gameCreator1,
    gameCreator2,
    user1,
    user2,
    GameKeys,
    gamekeys;
  const DEFAULT_ADMIN_ROLE = ethers.constants.HashZero;
  const ADMIN_ROLE = ethers.utils.id('ADMIN_ROLE');
  const RATE = 1e15;
  beforeEach(async function () {
    [
      deployer,
      admin,
      gameCreator1,
      gameCreator2,
      user1,
      user2,
    ] = await ethers.getSigners();
    GameKeys = await ethers.getContractFactory('GameKeys');
    gamekeys = await GameKeys.connect(deployer).deploy(admin.address);
    await gamekeys.deployed();
  });

  describe('GameKeys deployment + AccessControl Roles', function () {
    it('Should have an admin', async function () {
      expect(await gamekeys.admin()).to.equal(admin.address);
    });
    it('Should have admin as administrator', async function () {
      expect(await gamekeys.isAdmin(admin.address)).to.be.true;
    });
    it('Should have admin ADMIN_ROLE', async function () {
      expect(await gamekeys.hasRole(ADMIN_ROLE, admin.address)).to.be.true;
    });
    it('Should have deployer has DEFAULT_ADMIN_ROLE', async function () {
      expect(await gamekeys.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be.true;
    });
  });

  describe('Function registerNewGame', function () {
    let tx;
    beforeEach(async function () {
      await gamekeys.connect(admin).addGameCreator(gameCreator1.address);
      await gamekeys.connect(gameCreator1).registerNewGame('Snake', 'https://snake.com/png', 'blablabla', 5);
    });
    it('Should set gameCreator1 as GAME_CREATOR_ROLE', async function () {
      await gamekeys.connect(admin).addGameCreator(gameCreator1.address);
      expect(await gamekeys.isGameCreator(gameCreator1.address)).to.be.true;
    });
    it('Should register new game', async function () {
      expect(await gamekeys.isGameRegisteredById(1)).to.be.true;
    });
    it('Should emit NewGameRegistered event', async function () {
      tx = gamekeys.connect(gameCreator1).registerNewGame('PacMan', 'https://pacman.com/png', 'hello pacman', 6);
      await expect(tx).to.emit(gamekeys, 'NewGameRegistered').withArgs(gameCreator1.address, 2, 6 * RATE);
    });
    it('Should revert if game already exists', async function () {
      await gamekeys.connect(admin).addGameCreator(gameCreator2.address);
      tx = gamekeys.connect(gameCreator2).registerNewGame('Snake', 'https://snake.gc2.com/png', 'blabliblo', 4);
      await expect(tx).to.revertedWith('GameKeys: This Game already exists');
    });
    it('Should return the right struct of the game', async function () {
      const game = await gamekeys.connect(user1).getGameInfosById(1);
      expect(game.title).to.equal('Snake');
      expect(game.cover).to.equal('https://snake.com/png');
      expect(game.creator).to.equal(gameCreator1.address);
      expect(game.description).to.equal('blablabla');
      expect(game.price).to.equal(5 * RATE);
      // expect(game.gameHash).to.equal(ethers.utils.id('Snake'));
      // todo timestamp
    });
  });
  describe('Function BuyGame', async function () {
    let tx;
    beforeEach(async function () {
      await gamekeys.connect(admin).addGameCreator(gameCreator2.address);
      await gamekeys.connect(gameCreator2).registerNewGame('Mario', 'https://mario.com/png', 'blabliblou', 3);
      await gamekeys.connect(gameCreator2).registerNewGame('Snake', 'https://snake.com/png', 'blablabla', 5);
    });
    it('Should check if game id 1 is registered', async function () {
      expect(await gamekeys.isGameRegisteredById(1)).to.be.true;
    });
    it('Should check if game id 2 is registered', async function () {
      expect(await gamekeys.isGameRegisteredById(2)).to.be.true;
    });
    it('Should mint license game 1 to user1', async function () {
      await gamekeys.connect(user1).buyGame(1, { value: ethers.utils.parseEther('0.003') });
      expect(await gamekeys.balanceOf(user1.address)).to.equal(1);
    });
    it('Should mint license game 2 to user2', async function () {
      await gamekeys.connect(user2).buyGame(2, { value: ethers.utils.parseEther('0.005') });
      expect(await gamekeys.balanceOf(user2.address)).to.equal(1);
    });
    it('Should emit GameBought event', async function () {
      tx = gamekeys.connect(user1).buyGame(2, { value: ethers.utils.parseEther('0.005') });
      await expect(tx).to.emit(gamekeys, 'GameBought').withArgs(user1.address, 2, 1, 5 * RATE);
    });
    it('Should revert if game is not registered', async function () {
      tx = gamekeys.connect(user2).buyGame(3, { value: ethers.utils.parseEther('0.006') });
      await expect(tx).to.revertedWith('GameKeys: Sorry this game does not exists');
    });
    it('Should revert if msg.value not enough', async function () {
      tx = gamekeys.connect(user2).buyGame(1, { value: ethers.utils.parseEther('0.002') });
      await expect(tx).to.revertedWith('GameKeys: Sorry not enought ethers');
    });
  });
  describe('Function Withdraw', async function () {
    let tx, user1AddressTLC, GAME_CREATOR_ROLE;
    beforeEach(async function () {
      await gamekeys.connect(admin).addGameCreator(gameCreator2.address);
      await gamekeys.connect(gameCreator2).registerNewGame('Mario', 'https://mario.com/png', 'blabliblou', 3);
      await gamekeys.connect(gameCreator2).registerNewGame('Snake', 'https://snake.com/png', 'blablabla', 5);
      await gamekeys.connect(user1).buyGame(1, { value: ethers.utils.parseEther('0.003') });
      await gamekeys.connect(user2).buyGame(2, { value: ethers.utils.parseEther('0.005') });
    });
    it('Should check the gameCreator2 balances', async function () {
      tx = ethers.utils.parseEther('0.008');
      expect(await gamekeys.connect(gameCreator2).getCreatorBalance(gameCreator2.address)).to.equal(tx);
    });
    it('Should send ethers and reset balances of gameCreator2', async function () {
      await expect(() => gamekeys.connect(gameCreator2).withdraw())
        .to.changeEtherBalance(gameCreator2, (await ethers.utils.parseEther('0.008')));
      expect(await gamekeys.connect(gameCreator2).getCreatorBalance(gameCreator2.address)).to.equal(0);
    });
    it('Should emit GameBenefitsWithdrew event', async function () {
      tx = gamekeys.connect(gameCreator2).withdraw();
      await expect(tx).to.emit(gamekeys, 'GameBenefitsWithdrew').withArgs(gameCreator2.address, 8 * RATE);
    });
    it('Should revert if function is not called by GAME_CREATOR_ROLE', async function () {
      GAME_CREATOR_ROLE = ethers.utils.id('GAME_CREATOR_ROLE');
      user1AddressTLC = (user1.address).toLowerCase();
      tx = gamekeys.connect(user1).withdraw();
      await expect(tx)
        .to
        .revertedWith(
          `AccessControl: account ${user1AddressTLC} is missing role ${GAME_CREATOR_ROLE}`);
    });
    it('Should revert if no balances to withdraw', async function () {
      await gamekeys.connect(admin).addGameCreator(gameCreator1.address);
      tx = gamekeys.connect(gameCreator1).withdraw();
      await expect(tx).to.revertedWith('GameKeys: Sorry balances are empty, nothing to withdraw');
    });
  });
});
