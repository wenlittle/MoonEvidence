package chaincode

import (
	"errors"
	"strings"
	"testing"
)

const (
	testSHA256 = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	testSHA512 = "sha512:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
)

type fakeState struct {
	values    map[string][]byte
	txID      string
	readErr   error
	writeErr  error
	eventErr  error
	eventName string
	eventData []byte
	eventHits int
}

func newFakeState() *fakeState {
	return &fakeState{values: map[string][]byte{}, txID: "tx-first"}
}

func (f *fakeState) GetState(key string) ([]byte, error) {
	if f.readErr != nil {
		return nil, f.readErr
	}
	return append([]byte(nil), f.values[key]...), nil
}

func (f *fakeState) PutState(key string, value []byte) error {
	if f.writeErr != nil {
		return f.writeErr
	}
	f.values[key] = append([]byte(nil), value...)
	return nil
}

func (f *fakeState) GetTxID() string {
	return f.txID
}

func (f *fakeState) SetEvent(name string, payload []byte) error {
	if f.eventErr != nil {
		return f.eventErr
	}
	f.eventName = name
	f.eventData = append([]byte(nil), payload...)
	f.eventHits++
	return nil
}

type fakeIdentity struct {
	mspID string
	err   error
}

func (f fakeIdentity) GetMSPID() (string, error) {
	return f.mspID, f.err
}

func requireErrorPrefix(t *testing.T, err error, prefix string) {
	t.Helper()
	if err == nil || !strings.HasPrefix(err.Error(), prefix) {
		t.Fatalf("expected error prefix %q, got %v", prefix, err)
	}
}

func TestValidateDigest(t *testing.T) {
	for _, valid := range []string{testSHA256, testSHA512} {
		if err := validateDigest(valid); err != nil {
			t.Fatalf("valid digest %q rejected: %v", valid, err)
		}
	}
	for _, invalid := range []string{
		"",
		"sha256:ABC",
		"sha256:0123",
		"md5:0123456789abcdef0123456789abcdef",
		"sha512:" + strings.Repeat("0", 127),
	} {
		requireErrorPrefix(t, validateDigest(invalid), "MEANCHOR_INVALID_DIGEST")
	}
}

func TestCreateAnchorFirstWrite(t *testing.T) {
	state := newFakeState()
	result, err := createAnchor(state, "Org1MSP", testSHA256)
	if err != nil {
		t.Fatalf("create anchor: %v", err)
	}
	if !result.Created {
		t.Fatal("first create should report created=true")
	}
	if result.Anchor.ManifestDigest != testSHA256 ||
		result.Anchor.TransactionID != "tx-first" ||
		result.Anchor.SubmitterMSP != "Org1MSP" ||
		result.Anchor.Schema != anchorSchema {
		t.Fatalf("unexpected anchor: %#v", result.Anchor)
	}
	const expectedJSONPrefix = `{"schema":"moon-evidence-anchor/v1","manifest_digest":"sha256:`
	value := string(state.values[stateKey(testSHA256)])
	if !strings.HasPrefix(value, expectedJSONPrefix) {
		t.Fatalf("state is not deterministic anchor JSON: %s", value)
	}
	if state.eventName != anchorEvent || state.eventHits != 1 ||
		string(state.eventData) != value {
		t.Fatalf("unexpected event: name=%q hits=%d payload=%s", state.eventName, state.eventHits, state.eventData)
	}
}

func TestCreateAnchorSequentialDuplicateIsIdempotent(t *testing.T) {
	state := newFakeState()
	first, err := createAnchor(state, "Org1MSP", testSHA256)
	if err != nil {
		t.Fatalf("first create: %v", err)
	}
	firstBytes := append([]byte(nil), state.values[stateKey(testSHA256)]...)
	state.txID = "tx-retry"
	second, err := createAnchor(state, "Org2MSP", testSHA256)
	if err != nil {
		t.Fatalf("duplicate create: %v", err)
	}
	if second.Created {
		t.Fatal("duplicate should report created=false")
	}
	if second.Anchor.TransactionID != first.Anchor.TransactionID ||
		second.Anchor.SubmitterMSP != first.Anchor.SubmitterMSP {
		t.Fatalf("duplicate did not preserve original record: %#v", second.Anchor)
	}
	if string(firstBytes) != string(state.values[stateKey(testSHA256)]) {
		t.Fatal("duplicate overwrote state")
	}
	if state.eventHits != 1 {
		t.Fatalf("duplicate emitted another event: %d", state.eventHits)
	}
}

func TestReadAndExists(t *testing.T) {
	state := newFakeState()
	exists, err := anchorExists(state, testSHA256)
	if err != nil || exists {
		t.Fatalf("missing anchor exists=%v err=%v", exists, err)
	}
	if _, err := createAnchor(state, "Org1MSP", testSHA256); err != nil {
		t.Fatalf("create: %v", err)
	}
	exists, err = anchorExists(state, testSHA256)
	if err != nil || !exists {
		t.Fatalf("stored anchor exists=%v err=%v", exists, err)
	}
	record, err := readAnchor(state, testSHA256)
	if err != nil || record.TransactionID != "tx-first" {
		t.Fatalf("read anchor=%#v err=%v", record, err)
	}
	requireErrorPrefix(t, mustReadError(state, testSHA512), "MEANCHOR_NOT_FOUND")
}

func mustReadError(state anchorState, digest string) error {
	_, err := readAnchor(state, digest)
	return err
}

func TestCorruptStateIsNeverAcceptedOrOverwritten(t *testing.T) {
	for name, value := range map[string][]byte{
		"invalid json": []byte("{"),
		"wrong digest": []byte(`{"schema":"moon-evidence-anchor/v1","manifest_digest":"sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","transaction_id":"tx","submitter_msp":"Org1MSP"}`),
		"wrong schema": []byte(`{"schema":"other","manifest_digest":"` + testSHA256 + `","transaction_id":"tx","submitter_msp":"Org1MSP"}`),
	} {
		t.Run(name, func(t *testing.T) {
			state := newFakeState()
			state.values[stateKey(testSHA256)] = value
			_, err := createAnchor(state, "Org1MSP", testSHA256)
			requireErrorPrefix(t, err, "MEANCHOR_CORRUPT_STATE")
			if string(state.values[stateKey(testSHA256)]) != string(value) {
				t.Fatal("corrupt existing state was overwritten")
			}
			_, err = anchorExists(state, testSHA256)
			requireErrorPrefix(t, err, "MEANCHOR_CORRUPT_STATE")
		})
	}
}

func TestStateFailuresAndContextRequirements(t *testing.T) {
	state := newFakeState()
	state.readErr = errors.New("read down")
	_, err := createAnchor(state, "Org1MSP", testSHA256)
	requireErrorPrefix(t, err, "MEANCHOR_READ_FAILED")

	state = newFakeState()
	state.writeErr = errors.New("write down")
	_, err = createAnchor(state, "Org1MSP", testSHA256)
	requireErrorPrefix(t, err, "MEANCHOR_WRITE_FAILED")

	state = newFakeState()
	state.eventErr = errors.New("event down")
	_, err = createAnchor(state, "Org1MSP", testSHA256)
	requireErrorPrefix(t, err, "MEANCHOR_EVENT_FAILED")

	state = newFakeState()
	state.txID = ""
	_, err = createAnchor(state, "Org1MSP", testSHA256)
	requireErrorPrefix(t, err, "MEANCHOR_TXID_MISSING")

	state = newFakeState()
	_, err = createAnchor(state, "", testSHA256)
	requireErrorPrefix(t, err, "MEANCHOR_IDENTITY_FAILED")
}

func TestInvokingMSP(t *testing.T) {
	mspID, err := invokingMSP(fakeIdentity{mspID: "Org1MSP"})
	if err != nil || mspID != "Org1MSP" {
		t.Fatalf("mspID=%q err=%v", mspID, err)
	}
	_, err = invokingMSP(fakeIdentity{err: errors.New("bad certificate")})
	requireErrorPrefix(t, err, "MEANCHOR_IDENTITY_FAILED")
	_, err = invokingMSP(fakeIdentity{})
	requireErrorPrefix(t, err, "MEANCHOR_IDENTITY_FAILED")
}
