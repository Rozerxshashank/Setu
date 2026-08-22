const { expect } = require('chai');
const sinon = require('sinon');
const admin = require('firebase-admin');

// 1. Initialize offline test mode
const test = require('firebase-functions-test')();

// 2. Require index.js which will call admin.initializeApp() and admin.firestore()
const myFunctions = require('../index.js');
const { SpeechClient } = require('@google-cloud/speech');
const { GoogleGenerativeAI } = require('@google/generative-ai');

describe('Step 4 Pipeline Logic', () => {
  let generateContentStub;
  let firestoreStub;
  let storageStub;

  beforeEach(() => {
    // 3. Stub the actual methods on the initialized db and bucket
    const db = admin.firestore();
    firestoreStub = sinon.stub(db, 'collection');
    sinon.stub(db, 'runTransaction').callsFake(async (cb) => {
        const transactionMock = {
            get: sinon.stub().callsFake(async (ref) => {
                if (ref && ref.get) return ref.get();
                return { exists: false, data: () => ({}) };
            }),
            set: sinon.stub().callsFake((ref, data) => {
                if (ref && ref.create) ref.create(data);
            }),
            update: sinon.stub()
        };
        return cb(transactionMock);
    });
    
    const storage = admin.storage();
    storageStub = sinon.stub(storage, 'bucket');
  });

  afterEach(() => {
    sinon.restore();
  });

  function setupMocks(existingLogExists = false, sttThrows = false, storagePath = 'audio_inbox/circle1/user1/test.m4a') {
    // Mock DB
    const docMock = {
      get: sinon.stub().resolves({
        exists: true,
        data: () => ({ memberIds: ['user1'], preferredLanguage: 'en' })
      }),
      collection: sinon.stub()
    };
    
    const logDocMock = {
       get: sinon.stub().resolves({ exists: existingLogExists }),
       create: sinon.stub().resolves(),
       id: 'log_test_m4a'
    };

    const taskDocMock = {
       get: sinon.stub().resolves({ exists: true, data: () => ({ status: 'pending' }) })
    };

    const tasksMock = {
       where: sinon.stub().returnsThis(),
       get: sinon.stub().resolves({ docs: [] }),
       doc: sinon.stub().returns(taskDocMock)
    };

    docMock.collection.withArgs('dailyLogs').returns({ doc: sinon.stub().returns(logDocMock) });
    docMock.collection.withArgs('tasks').returns(tasksMock);

    firestoreStub.withArgs('familyCircles').returns({
      doc: sinon.stub().returns(docMock)
    });

    // Mock Storage
    const fileMock = {
      exists: sinon.stub().resolves([true]),
      getMetadata: sinon.stub().resolves([{ size: 1000, contentType: 'audio/m4a' }])
    };
    storageStub.returns({
      file: sinon.stub().withArgs(storagePath).returns(fileMock),
      name: 'test-bucket'
    });

    // Mock STT
    if (sttThrows) {
       sinon.stub(SpeechClient.prototype, 'recognize').rejects(new Error('STT Engine Error'));
    } else {
       sinon.stub(SpeechClient.prototype, 'recognize').resolves([
         { results: [{ alternatives: [{ transcript: 'mock transcript' }] }] }
       ]);
    }

    return { logDocMock, fileMock };
  }

  it('computes RED status for explicit severe distress/request for help', async () => {
    const { logDocMock } = setupMocks();

    generateContentStub = sinon.stub().resolves({
      response: {
        text: () => JSON.stringify({
          sentiment: 'negative',
          medicationStatus: 'unclear',
          medicationsMentioned: [],
          flaggedConcerns: ['severe pain', 'request for help'],
          taskResponses: [],
          confidenceScore: 0.99,
          summary: 'Amma is in severe pain and needs help.'
        })
      }
    });

    sinon.stub(GoogleGenerativeAI.prototype, 'getGenerativeModel').returns({
      generateContent: generateContentStub
    });

    // Simulate callable
    const req = { data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/test.m4a' }, auth: { uid: 'user1' } };
    
    // Test wrap simulation
    const context = { auth: req.auth };
    const res = await myFunctions.processAudioCheckIn.run(req, context);

    expect(res.logId).to.equal('log_test_m4a');
    sinon.assert.calledWithMatch(logDocMock.create, { status: 'red', medicationTaken: null });
  });

  it('computes YELLOW status for minor explicit concern', async () => {
    const { logDocMock } = setupMocks();

    sinon.stub(GoogleGenerativeAI.prototype, 'getGenerativeModel').returns({
      generateContent: sinon.stub().resolves({
        response: {
          text: () => JSON.stringify({
            sentiment: 'negative',
            medicationStatus: 'taken',
            medicationsMentioned: ['morning pill'],
            flaggedConcerns: ['knee hurts a little'],
            taskResponses: [],
            confidenceScore: 0.9,
            summary: 'Amma says her knee hurts.'
          })
        }
      })
    });

    const req = { data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/test.m4a' }, auth: { uid: 'user1' } };
    const res = await myFunctions.processAudioCheckIn.run(req, { auth: req.auth });

    sinon.assert.calledWithMatch(logDocMock.create, { status: 'yellow', medicationTaken: true });
  });

  it('computes GREEN status for negative sentiment without a concern', async () => {
    const { logDocMock } = setupMocks();

    sinon.stub(GoogleGenerativeAI.prototype, 'getGenerativeModel').returns({
      generateContent: sinon.stub().resolves({
        response: {
          text: () => JSON.stringify({
            sentiment: 'negative', 
            medicationStatus: 'not_mentioned',
            medicationsMentioned: [],
            flaggedConcerns: [], // no explicit concern
            taskResponses: [],
            confidenceScore: 0.9,
            summary: 'Amma is bored.'
          })
        }
      })
    });

    const req = { data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/test.m4a' }, auth: { uid: 'user1' } };
    await myFunctions.processAudioCheckIn.run(req, { auth: req.auth });

    sinon.assert.calledWithMatch(logDocMock.create, { status: 'green', medicationTaken: null });
  });

  it('handles idempotency (existing log skips processing)', async () => {
    const { logDocMock } = setupMocks(true); // Existing log is TRUE
    
    // GenAI stub shouldn't be called, but we stub it anyway to prevent errors
    sinon.stub(GoogleGenerativeAI.prototype, 'getGenerativeModel').returns({
      generateContent: sinon.stub().rejects(new Error('Should not be called'))
    });

    const req = { data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/test.m4a' }, auth: { uid: 'user1' } };
    const res = await myFunctions.processAudioCheckIn.run(req, { auth: req.auth });

    expect(res.logId).to.equal('log_test_m4a');
    sinon.assert.notCalled(logDocMock.create); // Should not create a new one
  });

  it('handles errors cleanly (no DailyLog when STT fails)', async () => {
    setupMocks(false, true); // sttThrows = true

    const req = { data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/test.m4a' }, auth: { uid: 'user1' } };
    
    try {
      await myFunctions.processAudioCheckIn.run(req, { auth: req.auth });
      expect.fail('Should have thrown');
    } catch (e) {
      expect(e.message).to.include('STT processing failed');
    }
  });
});
