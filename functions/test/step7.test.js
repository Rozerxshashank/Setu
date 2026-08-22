const { expect } = require('chai');
const sinon = require('sinon');
const admin = require('firebase-admin');
const test = require('firebase-functions-test')();
const myFunctions = require('../index.js');
const { HttpsError } = require('firebase-functions/v2/https');
const { SpeechClient } = require('@google-cloud/speech');
const { GoogleGenerativeAI } = require('@google/generative-ai');

describe('Step 7: Task/Reminder Management Delivery', () => {
  let firestoreStub, storageStub, speechStub, genAIStub, runTransactionStub;
  let transactionMock;

  beforeEach(() => {
    // Stub storage
    const fileMock = {
      exists: sinon.stub().resolves([true]),
      getMetadata: sinon.stub().resolves([{ size: 1024, contentType: 'audio/m4a' }])
    };
    const bucketMock = { file: sinon.stub().returns(fileMock), name: 'test-bucket' };
    const storage = admin.storage();
    storageStub = sinon.stub(storage, 'bucket').returns(bucketMock);

    // Stub speech
    speechStub = sinon.stub(SpeechClient.prototype, 'recognize').resolves([
      { results: [{ alternatives: [{ transcript: 'I took my medicine and paid the bill.' }] }] }
    ]);

    // Stub genAI
    const modelMock = {
      generateContent: sinon.stub().resolves({
        response: {
          text: () => JSON.stringify({
            sentiment: 'positive',
            medicationStatus: 'taken',
            medicationsMentioned: [],
            flaggedConcerns: [],
            taskResponses: [
              { taskId: 'task1', response: 'Paid the bill', status: 'answered' },
              { taskId: 'task2', response: '', status: 'unanswered' }
            ],
            confidenceScore: 0.9,
            summary: 'All good.'
          })
        }
      })
    };
    genAIStub = sinon.stub(GoogleGenerativeAI.prototype, 'getGenerativeModel').returns(modelMock);

    // Stub Firestore
    const db = admin.firestore();
    firestoreStub = sinon.stub(db, 'collection');

    transactionMock = {
      get: sinon.stub(),
      set: sinon.stub(),
      update: sinon.stub()
    };
    
    runTransactionStub = sinon.stub(db, 'runTransaction').callsFake(async (fn) => {
      return await fn(transactionMock);
    });
  });

  afterEach(() => {
    sinon.restore();
  });

  function mockDb({
    isMember = true,
    logExists = false,
    tasks = []
  }) {
    const circleDoc = {
      exists: true,
      data: () => ({
        memberIds: isMember ? ['user1'] : [],
        preferredLanguage: 'english'
      })
    };

    const taskQueryMock = {
      get: sinon.stub().resolves({
        docs: tasks.map(t => ({ id: t.taskId, data: () => t }))
      })
    };

    const taskRefMock = { 
      where: sinon.stub().withArgs('status', '==', 'pending').returns(taskQueryMock),
      doc: sinon.stub().callsFake((id) => ({ id }))
    };

    const dailyLogDoc = { doc: sinon.stub().returns({ 
      id: 'log_audio_m4a',
      get: sinon.stub().resolves({ exists: logExists })
    }) };
    const circleColMock = {
      doc: sinon.stub().returns({
        get: sinon.stub().resolves(circleDoc),
        collection: sinon.stub().callsFake((col) => {
          if (col === 'tasks') return taskRefMock;
          if (col === 'dailyLogs') return dailyLogDoc;
        })
      })
    };

    firestoreStub.withArgs('familyCircles').returns(circleColMock);

    // Set transaction mock behaviors
    transactionMock.get.callsFake(async (ref) => {
      // Check if it's the logRef
      if (ref.id === 'log_audio_m4a') {
        return { exists: logExists };
      }
      
      // If it's a taskRef
      const task = tasks.find(t => t.taskId === ref.id);
      if (task) {
         return { exists: true, data: () => task };
      }
      return { exists: false };
    });
    
    return { circleColMock };
  }

  it('1. Member can trigger check-in containing tasks', async () => {
    mockDb({ isMember: true, tasks: [{ taskId: 'task1', text: 'Did you pay?', status: 'pending' }] });
    
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    await myFunctions.processAudioCheckIn.run(req);
    
    sinon.assert.calledWithMatch(transactionMock.update, sinon.match.has('id', 'task1'), {
      status: 'acknowledged' // because genAI stub returns 'answered' for task1
    });
  });

  it('2. Non-member cannot process audio', async () => {
    mockDb({ isMember: false });
    const req = { auth: { uid: 'user2' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user2/audio.m4a' } };
    
    try {
      await myFunctions.processAudioCheckIn.run(req);
      expect.fail('Should throw');
    } catch (e) {
      expect(e).to.be.instanceOf(HttpsError);
      expect(e.code).to.equal('permission-denied');
    }
  });

  it('3. Explicit answer -> acknowledged', async () => {
    mockDb({ isMember: true, tasks: [{ taskId: 'task1', text: 'Bill?', status: 'pending' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    // task1 is 'answered' in stub
    sinon.assert.calledWithMatch(transactionMock.update, sinon.match.has('id', 'task1'), {
      status: 'acknowledged'
    });
  });

  it('4. Unanswered -> delivered', async () => {
    mockDb({ isMember: true, tasks: [{ taskId: 'task2', text: 'Meds?', status: 'pending' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    // task2 is 'unanswered' in stub
    sinon.assert.calledWithMatch(transactionMock.update, sinon.match.has('id', 'task2'), {
      status: 'delivered'
    });
  });

  it('5. Missing response -> delivered', async () => {
    // task3 is missing from LLM response
    mockDb({ isMember: true, tasks: [{ taskId: 'task3', text: 'Sleep well?', status: 'pending' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    sinon.assert.calledWithMatch(transactionMock.update, sinon.match.has('id', 'task3'), {
      status: 'delivered'
    });
  });

  it('6. Invalid/cross-circle taskId -> ignored', async () => {
    // LLM stub returns task1 and task2, but circle only has task3
    mockDb({ isMember: true, tasks: [{ taskId: 'task3', text: 'Real task', status: 'pending' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    // task1 & task2 updates should NEVER happen
    sinon.assert.neverCalledWithMatch(transactionMock.update, sinon.match.has('id', 'task1'), sinon.match.any);
    sinon.assert.neverCalledWithMatch(transactionMock.update, sinon.match.has('id', 'task2'), sinon.match.any);
    // task3 should be 'delivered' (missing from LLM)
    sinon.assert.calledWithMatch(transactionMock.update, sinon.match.has('id', 'task3'), { status: 'delivered' });
  });

  it('7. Delivered cannot become pending (No downgrade)', async () => {
    // Start with task1 as 'delivered'
    mockDb({ isMember: true, tasks: [{ taskId: 'task1', text: 'Bill?', status: 'delivered' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    // Should NOT update task1 because it's no longer pending
    sinon.assert.neverCalledWithMatch(transactionMock.update, sinon.match.has('id', 'task1'), sinon.match.any);
  });
  
  it('8. Acknowledged cannot become delivered (No downgrade)', async () => {
    // Start with task1 as 'acknowledged'
    mockDb({ isMember: true, tasks: [{ taskId: 'task1', text: 'Bill?', status: 'acknowledged' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    // Should NOT update task1
    sinon.assert.neverCalledWithMatch(transactionMock.update, sinon.match.has('id', 'task1'), sinon.match.any);
  });

  it('9. Retry of the same check-in does not duplicate daily log or corrupt task', async () => {
    // First time log exists
    mockDb({ isMember: true, logExists: true, tasks: [{ taskId: 'task1', text: 'Bill?', status: 'pending' }] });
    const req = { auth: { uid: 'user1' }, data: { circleId: 'circle1', storagePath: 'audio_inbox/circle1/user1/audio.m4a' } };
    
    await myFunctions.processAudioCheckIn.run(req);
    
    // It returns early because log exists inside transaction
    sinon.assert.neverCalledWithMatch(transactionMock.set, sinon.match.has('id', 'log_audio_m4a'), sinon.match.any);
    sinon.assert.neverCalledWithMatch(transactionMock.update, sinon.match.has('id', 'task1'), sinon.match.any);
  });
});
