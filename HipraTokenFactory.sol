// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./ERC165.sol";
import "./IERC721.sol";
import "./IERC721Receiver.sol";

contract HipraTokenFactory is ERC165, IERC721 {

    address Owner;

    uint256 tokenCounter;

    struct ControlCheck{
        address controlOwner;
        string description;
        bool is_valid;
        uint256 timestamp;
        uint256 temperature;
        uint256 humidity;
        uint256 brightness;
    }

    struct Result{
        address resultOwner;
        string description;
        string result;
        uint256 timestamp;
    }

    mapping(uint256 => address) private _owners; //Find the owner of the token by tokenId
    mapping(uint256 => ControlCheck) private _tokenControlData; //Find the token Control data by tokenId
    mapping(uint256 => Result) private _tokenResultData; //Find the token Result data by tokenId
    mapping(uint256 => address) private _tokenErrorData; //Find the Sample address of the token by tokenId 
    mapping(address => address) private _samplePatient; //Find the patient address of the sample
    mapping(address => uint256[]) private _patientControlTokens; //Find the list of the control tokens by patient address
    mapping(address => uint256) private _patientResultToken; //Find the result token by patient address
    mapping(address => bool) private _sampleIsValid; //true => the sample is valid, false => the sample is not valid

    mapping (address => bool) private controllers; //List of the controlers by address
    mapping (address => bool) private researchers; //List of the researchers by address
    mapping (address => bool) private admins; //List of the admins by address

    uint256[] _sampleErrorTokens; //List of the error tokens

    constructor(){
        Owner = msg.sender;
        tokenCounter = 1;
        admins[msg.sender] = true;
        controllers[msg.sender] = true;
        researchers[msg.sender] = true;
    }

    modifier onlyOwner(){ //Only the Owner can access
        require(Owner ==msg.sender);
        _;
    }

    function addAdmin(address _address) public onlyOwner { //Set admin permissions
        require(!admins[_address]);
        admins[_address] = true;
    }

    function removeAdmin(address _address) public onlyOwner { //Set admin permissions
        require(!admins[_address]);
        delete admins[_address];
    }

    //Only the admins can access
    modifier onlyAdmin(){
        require(admins[msg.sender]);
        _;
    }

    //Set controllers permissions
    function addController(address _address) public onlyAdmin {
        require(!controllers[_address]);
        controllers[_address] = true;
    }

    //only the controllers can access
    modifier onlyController() {
        require(controllers[msg.sender]);
        _;
    }

    //Set researcher permissions
    function addResearcher(address _address) public onlyAdmin {
        require(!researchers[_address]);
        researchers[_address] = true;
    }

    //Only the researchers can access
    modifier onlyResearcher() {
        require(researchers[msg.sender]);
        _;
    }

    //Link the sample with the patient
    function setSample(address _id) public {
        _samplePatient[_id] = msg.sender;
        _sampleIsValid[_id] = true;
    }

    //Controller create a token and send to the sample owner
    function setControlCheck(address _id, bool _is_valid, string memory _description, uint256 _temperature, uint256 _humidity, uint256 _brightness) public onlyController {
        require(_sampleIsValid[_id]);
        ControlCheck memory c;

        c.controlOwner = msg.sender;
        c.description = _description;
        c.timestamp = block.timestamp;
        c.is_valid = _is_valid;
        c.temperature = _temperature;
        c.humidity = _humidity;
        c.brightness = _brightness;
        address patient = _samplePatient[_id];

        _tokenControlData[tokenCounter] = c;
        _safeMint(patient, tokenCounter);
        _patientControlTokens[patient].push(tokenCounter);

        tokenCounter++;

        if(!_is_valid){
            _sampleIsValid[_id] = false;
            _tokenErrorData[tokenCounter] = _id;
            _safeMint(Owner, tokenCounter);
            _sampleErrorTokens.push(tokenCounter);

            tokenCounter++;
        }
    }

    //Researcher create a token and send to the sample owner
    function setResults(address _id, string memory _description, string memory _result) public onlyResearcher {
        require(_sampleIsValid[_id]);
        Result memory r;

        r.resultOwner = msg.sender;
        r.description = _description;
        r.result = _result;
        r.timestamp = block.timestamp;
        address patient = _samplePatient[_id];

        _tokenResultData[tokenCounter] = r;
        _safeMint(patient, tokenCounter);
        _patientResultToken[patient] = tokenCounter;

        tokenCounter++;
    }

    //The admins know if the sample is valid and the address of the patient
    function getSampleValidation(address _id) public view onlyAdmin returns(bool, address){
        return (_sampleIsValid[_id], _samplePatient[_id]);
    }

    //Get the sample address of the token
    function getErrorTokenInfo(uint256 _tokenId) public view onlyAdmin returns(address){
        require(_owners[_tokenId] == Owner);
        return _tokenErrorData[_tokenId];
    }

    //Get the list of error tokens
    function getErrorTokens() public view onlyAdmin returns(uint256[] memory){
        return _sampleErrorTokens;
    }

    //Get the control info by tokenId
    function getControlTokenInfo(uint256 _tokenId) public view returns(ControlCheck memory){
        require(_owners[_tokenId] == msg.sender);
        return _tokenControlData[_tokenId];
    }

    //Get the list of control tokens
    function getMyControlTokens() public view returns(uint256[] memory){
        return _patientControlTokens[msg.sender];
    }

    //Get the result info by tokenid
    function getResultTokenInfo(uint256 _tokenId) public view returns(Result memory){
        require(_owners[_tokenId] == msg.sender);
        return _tokenResultData[_tokenId];
    }

    //Get the result token
    function getMyResultToken() public view returns(uint256){
        return _patientResultToken[msg.sender];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId || super.supportsInterface(interfaceId);
    }

    function _safeMint(address to, uint256 tokenId) private {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(address to, uint256 tokenId, bytes memory _data) private {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721 ERROR: transfer to non ERC721Receiver implementer");
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721 ERROR: mint to the zero adress");
        require(!_exists(tokenId), "ERC721 ERROR: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }


    function isContract(address _addr) private view returns (bool){
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool){
        return _owners[tokenId] != address(0);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual{

    }
    
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool){
        if(isContract(to)){
            try IERC721Receiver(to).onERC721Receiver(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Receiver.selector;
            }  catch (bytes memory reason) {
                if (reason.length == 0){
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
        return true;
    }
}