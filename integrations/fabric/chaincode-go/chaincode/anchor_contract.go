package chaincode

import (
	"encoding/json"
	"fmt"
	"regexp"

	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

const (
	anchorSchema = "moon-evidence-anchor/v1"
	anchorPrefix = "anchor:"
	anchorEvent  = "AnchorCreated"
)

var canonicalDigest = regexp.MustCompile(`^(sha256:[0-9a-f]{64}|sha512:[0-9a-f]{128})$`)

// AnchorContract stores immutable MoonEvidence manifest-digest anchors.
type AnchorContract struct {
	contractapi.Contract
}

// AnchorRecord is the complete ledger state for one canonical manifest digest.
type AnchorRecord struct {
	Schema         string `json:"schema"`
	ManifestDigest string `json:"manifest_digest"`
	TransactionID  string `json:"transaction_id"`
	SubmitterMSP   string `json:"submitter_msp"`
}

// CreateAnchorResult distinguishes a first write from a sequential retry.
type CreateAnchorResult struct {
	Created bool          `json:"created"`
	Anchor  *AnchorRecord `json:"anchor"`
}

type anchorState interface {
	GetState(string) ([]byte, error)
	PutState(string, []byte) error
	GetTxID() string
	SetEvent(string, []byte) error
}

type mspIdentity interface {
	GetMSPID() (string, error)
}

// CreateAnchor writes an anchor once and returns the original record on retry.
func (c *AnchorContract) CreateAnchor(
	ctx contractapi.TransactionContextInterface,
	manifestDigest string,
) (*CreateAnchorResult, error) {
	mspID, err := invokingMSP(ctx.GetClientIdentity())
	if err != nil {
		return nil, err
	}
	return createAnchor(ctx.GetStub(), mspID, manifestDigest)
}

// ReadAnchor returns the immutable record for a manifest digest.
func (c *AnchorContract) ReadAnchor(
	ctx contractapi.TransactionContextInterface,
	manifestDigest string,
) (*AnchorRecord, error) {
	return readAnchor(ctx.GetStub(), manifestDigest)
}

// AnchorExists reports whether a valid anchor record exists.
func (c *AnchorContract) AnchorExists(
	ctx contractapi.TransactionContextInterface,
	manifestDigest string,
) (bool, error) {
	return anchorExists(ctx.GetStub(), manifestDigest)
}

func invokingMSP(identity mspIdentity) (string, error) {
	mspID, err := identity.GetMSPID()
	if err != nil {
		return "", fmt.Errorf("MEANCHOR_IDENTITY_FAILED: get invoking MSP: %w", err)
	}
	if mspID == "" {
		return "", fmt.Errorf("MEANCHOR_IDENTITY_FAILED: invoking MSP is empty")
	}
	return mspID, nil
}

func createAnchor(
	state anchorState,
	submitterMSP string,
	manifestDigest string,
) (*CreateAnchorResult, error) {
	if err := validateDigest(manifestDigest); err != nil {
		return nil, err
	}
	key := stateKey(manifestDigest)
	existing, err := state.GetState(key)
	if err != nil {
		return nil, fmt.Errorf("MEANCHOR_READ_FAILED: read %s: %w", key, err)
	}
	if len(existing) != 0 {
		record, err := decodeAnchor(existing, manifestDigest)
		if err != nil {
			return nil, err
		}
		return &CreateAnchorResult{Created: false, Anchor: record}, nil
	}
	if submitterMSP == "" {
		return nil, fmt.Errorf("MEANCHOR_IDENTITY_FAILED: invoking MSP is empty")
	}
	txID := state.GetTxID()
	if txID == "" {
		return nil, fmt.Errorf("MEANCHOR_TXID_MISSING: transaction ID is empty")
	}
	record := &AnchorRecord{
		Schema:         anchorSchema,
		ManifestDigest: manifestDigest,
		TransactionID:  txID,
		SubmitterMSP:   submitterMSP,
	}
	value, err := json.Marshal(record)
	if err != nil {
		return nil, fmt.Errorf("MEANCHOR_WRITE_FAILED: encode anchor: %w", err)
	}
	if err := state.PutState(key, value); err != nil {
		return nil, fmt.Errorf("MEANCHOR_WRITE_FAILED: write %s: %w", key, err)
	}
	if err := state.SetEvent(anchorEvent, value); err != nil {
		return nil, fmt.Errorf("MEANCHOR_EVENT_FAILED: emit %s: %w", anchorEvent, err)
	}
	return &CreateAnchorResult{Created: true, Anchor: record}, nil
}

func readAnchor(state anchorState, manifestDigest string) (*AnchorRecord, error) {
	if err := validateDigest(manifestDigest); err != nil {
		return nil, err
	}
	key := stateKey(manifestDigest)
	value, err := state.GetState(key)
	if err != nil {
		return nil, fmt.Errorf("MEANCHOR_READ_FAILED: read %s: %w", key, err)
	}
	if len(value) == 0 {
		return nil, fmt.Errorf("MEANCHOR_NOT_FOUND: %s", manifestDigest)
	}
	return decodeAnchor(value, manifestDigest)
}

func anchorExists(state anchorState, manifestDigest string) (bool, error) {
	if err := validateDigest(manifestDigest); err != nil {
		return false, err
	}
	key := stateKey(manifestDigest)
	value, err := state.GetState(key)
	if err != nil {
		return false, fmt.Errorf("MEANCHOR_READ_FAILED: read %s: %w", key, err)
	}
	if len(value) == 0 {
		return false, nil
	}
	if _, err := decodeAnchor(value, manifestDigest); err != nil {
		return false, err
	}
	return true, nil
}

func validateDigest(manifestDigest string) error {
	if !canonicalDigest.MatchString(manifestDigest) {
		return fmt.Errorf(
			"MEANCHOR_INVALID_DIGEST: expected canonical sha256:<64 lowercase hex> or sha512:<128 lowercase hex>",
		)
	}
	return nil
}

func stateKey(manifestDigest string) string {
	return anchorPrefix + manifestDigest
}

func decodeAnchor(value []byte, expectedDigest string) (*AnchorRecord, error) {
	var record AnchorRecord
	if err := json.Unmarshal(value, &record); err != nil {
		return nil, fmt.Errorf("MEANCHOR_CORRUPT_STATE: decode anchor: %w", err)
	}
	if record.Schema != anchorSchema ||
		record.ManifestDigest != expectedDigest ||
		record.TransactionID == "" ||
		record.SubmitterMSP == "" {
		return nil, fmt.Errorf(
			"MEANCHOR_CORRUPT_STATE: record does not match key or required schema",
		)
	}
	return &record, nil
}
