const { assertFails, assertSucceeds, initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { expect } = require('chai');
const fs = require('fs');
const path = require('path');

let testEnv;

before(async () => {
  // Use a unique project ID for this test run
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-setu-rules-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe('Setu Firestore Security Rules', () => {
  it('should allow users to read their own profile', async () => {
    const user = testEnv.authenticatedContext('alice', { email: 'alice@example.com' });
    const profileRef = user.firestore().collection('users').doc('alice');
    
    await assertSucceeds(profileRef.get());
  });

  it('should deny users from reading other profiles', async () => {
    const user = testEnv.authenticatedContext('alice');
    const profileRef = user.firestore().collection('users').doc('bob');
    
    await assertFails(profileRef.get());
  });

  it('should deny client-side creation of family circles', async () => {
    const user = testEnv.authenticatedContext('alice');
    const circleRef = user.firestore().collection('familyCircles').doc('circle1');
    
    await assertFails(circleRef.set({
      elderName: 'Amma',
      memberIds: ['alice']
    }));
  });

  it('should allow member to read their family circle', async () => {
    // Setup existing circle using admin context
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('familyCircles').doc('circle1').set({
        elderName: 'Amma',
        memberIds: ['alice']
      });
    });

    const user = testEnv.authenticatedContext('alice');
    const circleRef = user.firestore().collection('familyCircles').doc('circle1');
    
    await assertSucceeds(circleRef.get());
  });

  it('should deny non-member from reading family circle', async () => {
    // Setup existing circle using admin context
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('familyCircles').doc('circle1').set({
        elderName: 'Amma',
        memberIds: ['alice']
      });
    });

    const user = testEnv.authenticatedContext('bob');
    const circleRef = user.firestore().collection('familyCircles').doc('circle1');
    
    await assertFails(circleRef.get());
  });
  
  it('should deny all client updates to family circles', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('familyCircles').doc('circle1').set({
        elderName: 'Amma',
        memberIds: ['alice']
      });
    });

    const user = testEnv.authenticatedContext('alice');
    const circleRef = user.firestore().collection('familyCircles').doc('circle1');
    
    await assertFails(circleRef.update({ elderName: 'Mummy' }));
  });

  it('should allow members to read tasks and deny non-members', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('familyCircles').doc('circle1').set({
        memberIds: ['alice']
      });
      await context.firestore().collection('familyCircles').doc('circle1').collection('tasks').doc('task1').set({
        text: 'Give medicine'
      });
    });

    const alice = testEnv.authenticatedContext('alice');
    const bob = testEnv.authenticatedContext('bob');
    
    await assertSucceeds(alice.firestore().collection('familyCircles').doc('circle1').collection('tasks').doc('task1').get());
    await assertFails(bob.firestore().collection('familyCircles').doc('circle1').collection('tasks').doc('task1').get());
  });
});
