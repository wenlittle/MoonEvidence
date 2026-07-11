package main

import (
	"log"

	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
	"github.com/wenlittle/moonevidence/integrations/fabric/chaincode-go/chaincode"
)

func main() {
	anchorChaincode, err := contractapi.NewChaincode(&chaincode.AnchorContract{})
	if err != nil {
		log.Panicf("create MoonEvidence anchor chaincode: %v", err)
	}
	if err := anchorChaincode.Start(); err != nil {
		log.Panicf("start MoonEvidence anchor chaincode: %v", err)
	}
}
