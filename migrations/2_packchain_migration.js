const Packchain = artifacts.require("PackChain");

module.exports = function (deployer) {
  deployer.deploy(Packchain);
};
