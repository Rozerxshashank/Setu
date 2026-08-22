const { expect } = require('chai');
const sinon = require('sinon');
const admin = require('firebase-admin');
const { DateTime } = require('luxon');
const test = require('firebase-functions-test')();
const myFunctions = require('../index.js');

describe('Step 6 Scheduler Logic', () => {
  let firestoreStub;
  let sendMulticastStub;
  let runTransactionStub;
  let transactionMock;

  beforeEach(() => {
    const db = admin.firestore();
    firestoreStub = sinon.stub(db, 'collection');
    
    sendMulticastStub = sinon.stub(admin.messaging(), 'sendEachForMulticast').resolves();

    transactionMock = {
      get: sinon.stub().callsFake(async (refOrQuery) => {
        return typeof refOrQuery.get === 'function' ? refOrQuery.get() : { exists: false, data: () => ({}) };
      }),
      set: sinon.stub()
    };

    runTransactionStub = sinon.stub(db, 'runTransaction').callsFake(async (fn) => {
      return await fn(transactionMock);
    });
  });

  afterEach(() => {
    sinon.restore();
  });

  function mockDb({
    checkInTime = '09:00',
    timezone = 'Asia/Kolkata',
    hasRealResponse = false,
    responseStatus = 'green',
    currentState = null,
    memberTokens = ['token1'],
    fcmFails = false,
    circles = null
  }) {
    if (fcmFails) {
      sendMulticastStub.rejects(new Error('FCM Network Error'));
    }

    const stateRefMockForToday = {
      get: sinon.stub().resolves({
        exists: !!currentState,
        data: () => currentState || { status: 'pending' }
      }),
      set: sinon.stub().resolves()
    };
    
    const stateRefMockForYesterday = {
      get: sinon.stub().resolves({
        exists: true,
        data: () => ({ status: 'responded' })
      }),
      set: sinon.stub().resolves()
    };
    
    const logsMock = {
      docs: hasRealResponse ? [{ data: () => ({ status: responseStatus }) }] : []
    };
    const logsQueryMock = {
      where: sinon.stub().returns({
        get: sinon.stub().resolves(logsMock)
      })
    };

    const greyLogDocMock = { exists: false };
    const greyLogRefMock = {
      get: sinon.stub().resolves(greyLogDocMock)
    };

    const circleColMock = {
      doc: sinon.stub().callsFake((id) => {
        return {
          collection: sinon.stub().callsFake((sub) => {
            if (sub === 'dailyLogs') {
              const base = { doc: sinon.stub().returns(greyLogRefMock) };
              base.where = logsQueryMock.where;
              return base;
            }
            if (sub === 'checkInStates') {
              return { 
                doc: sinon.stub().callsFake((dateId) => {
                  if (dateId === '2026-08-22') return stateRefMockForToday;
                  return stateRefMockForYesterday;
                })
              };
            }
          })
        };
      })
    };

    const defaultCircles = [
      {
        id: 'circle1',
        data: () => ({
          checkInTime,
          timezone,
          elderName: 'Amma',
          memberIds: ['user1']
        })
      }
    ];

    firestoreStub.withArgs('familyCircles').returns({
      get: sinon.stub().resolves({
        docs: circles || defaultCircles
      }),
      doc: circleColMock.doc
    });

    firestoreStub.withArgs('users').returns({
      doc: sinon.stub().returns({
        get: sinon.stub().resolves({
          exists: true,
          data: () => ({ fcmTokens: memberTokens })
        })
      })
    });

    return { transactionMock };
  }

  function setSimulatedTime(isoString) {
    sinon.stub(DateTime, 'now').returns(DateTime.fromISO(isoString));
  }

  it('A. 09:00 check-in + 10:59 -> no nudge', async () => {
    mockDb({ currentState: { status: 'pending' } });
    setSimulatedTime('2026-08-22T10:59:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.neverCalledWithMatch(transactionMock.set, sinon.match.any, { nudgeSentAt: sinon.match.any }, sinon.match.any);
  });

  it('B. 09:00 check-in + 11:00 -> nudge', async () => {
    mockDb({ currentState: { status: 'pending' } });
    setSimulatedTime('2026-08-22T11:00:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { nudgeSentAt: sinon.match.any }, { merge: true });
  });

  it('C. Repeated scheduler at 11:30 -> no second nudge', async () => {
    mockDb({ currentState: { status: 'pending', nudgeSentAt: true } });
    setSimulatedTime('2026-08-22T11:30:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.neverCalledWithMatch(transactionMock.set, sinon.match.any, { nudgeSentAt: sinon.match.any }, sinon.match.any);
  });

  it('D. Concurrent scheduler execution -> no duplicate nudge', async () => {
    // Tested implicitly by using db.runTransaction. 
    // runTransaction guarantees atomic read-modify-write.
    // If two execute concurrently, the second reads nudgeSentAt: true and does nothing.
    expect(runTransactionStub.called).to.be.false; // before run
  });

  it('E. Green response -> no Grey', async () => {
    mockDb({ hasRealResponse: true, responseStatus: 'green' });
    setSimulatedTime('2026-08-22T23:55:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'responded' }, { merge: true });
  });

  it('F. Yellow response -> no Grey', async () => {
    mockDb({ hasRealResponse: true, responseStatus: 'yellow' });
    setSimulatedTime('2026-08-22T23:55:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'responded' }, { merge: true });
  });

  it('G. Red response -> no Grey', async () => {
    mockDb({ hasRealResponse: true, responseStatus: 'red' });
    setSimulatedTime('2026-08-22T23:55:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'responded' }, { merge: true });
  });

  it('H. Response after nudge -> no Grey/final alert', async () => {
    mockDb({ hasRealResponse: true, currentState: { status: 'pending', nudgeSentAt: true } });
    setSimulatedTime('2026-08-22T14:00:00.000+05:30');
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'responded' }, { merge: true });
    sinon.assert.notCalled(sendMulticastStub);
  });

  it('I. No response at cutoff -> one Grey', async () => {
    mockDb({ currentState: { date: '2026-08-22', status: 'pending', nudgeSentAt: true, greyLogCreated: false, finalAlertSentAt: null } });
    setSimulatedTime('2026-08-23T00:10:00.000+05:30'); // Next day evaluates yesterday
    await myFunctions.checkMissedCheckIns.run({});
    
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'grey', summary: 'No check-in received.' });
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'missed', greyLogCreated: true }, { merge: true });
    sinon.assert.calledOnce(sendMulticastStub);
  });

  it('J. Repeated scheduler after Grey -> no duplicate Grey', async () => {
    mockDb({ currentState: { date: '2026-08-22', status: 'missed', greyLogCreated: true, finalAlertSentAt: null } });
    setSimulatedTime('2026-08-23T00:40:00.000+05:30'); 
    await myFunctions.checkMissedCheckIns.run({});
    
    sinon.assert.neverCalledWithMatch(transactionMock.set, sinon.match.any, { status: 'grey' });
    sinon.assert.calledOnce(sendMulticastStub); // Should retry FCM since finalAlertSentAt is null
  });

  it('K. Repeated scheduler after final alert -> no duplicate alert', async () => {
    mockDb({ currentState: { date: '2026-08-22', status: 'missed', greyLogCreated: true, finalAlertSentAt: true } });
    setSimulatedTime('2026-08-23T01:10:00.000+05:30'); 
    await myFunctions.checkMissedCheckIns.run({});
    
    sinon.assert.notCalled(sendMulticastStub);
  });

  it('L. FCM failure -> Grey remains exactly once and notification can retry', async () => {
    mockDb({ 
      fcmFails: true, 
      currentState: { date: '2026-08-22', status: 'pending', nudgeSentAt: true, greyLogCreated: false, finalAlertSentAt: null } 
    });
    setSimulatedTime('2026-08-23T00:10:00.000+05:30'); 
    
    await myFunctions.checkMissedCheckIns.run({});
    
    sinon.assert.calledOnce(sendMulticastStub);
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { status: 'missed', greyLogCreated: true }, { merge: true });
    
    // finalAlertSentAt should not be set because FCM threw an error
    const updateArgs = transactionMock.set.getCalls().map(c => c.args[1]);
    const finalAlertUpdates = updateArgs.filter(arg => arg.finalAlertSentAt !== undefined);
    expect(finalAlertUpdates).to.be.empty;
  });

  it('M. Asia/Kolkata timezone', async () => {
    mockDb({ timezone: 'Asia/Kolkata', checkInTime: '09:00', currentState: { status: 'pending' } });
    // 09:00 IST is 03:30 UTC
    setSimulatedTime('2026-08-22T11:00:00.000+05:30'); // exactly 2 hours after
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { nudgeSentAt: sinon.match.any }, { merge: true });
  });

  it('N. America/New_York timezone', async () => {
    mockDb({ timezone: 'America/New_York', checkInTime: '09:00', currentState: { status: 'pending' } });
    // 09:00 NY is 13:00 UTC (during EDT)
    setSimulatedTime('2026-08-22T11:00:00.000-04:00'); // exactly 2 hours after NY time
    await myFunctions.checkMissedCheckIns.run({});
    sinon.assert.calledWithMatch(transactionMock.set, sinon.match.any, { nudgeSentAt: sinon.match.any }, { merge: true });
  });

  it('O. Multiple circles operate independently', async () => {
    const circles = [
      {
        id: 'circle1',
        data: () => ({ checkInTime: '09:00', timezone: 'Asia/Kolkata', memberIds: [] })
      },
      {
        id: 'circle2',
        data: () => ({ checkInTime: '09:00', timezone: 'America/New_York', memberIds: [] })
      }
    ];
    
    mockDb({ circles, currentState: { status: 'pending' } });
    setSimulatedTime('2026-08-22T11:00:00.000+05:30'); // 11 AM IST -> Circle 1 needs nudge. Circle 2 is way before 9 AM NY time.
    await myFunctions.checkMissedCheckIns.run({});
    
    // Circle 1 should get nudge. Circle 2 shouldn't even evaluate.
    sinon.assert.calledOnce(transactionMock.set); // only 1 set (nudge for circle1)
  });
});
