const Packchain = artifacts.require("Packchain");

module.exports = function (deployer) {
  deployer.deploy(Packchain);
};
