// Tests for ProcessMode.shouldProcess

@Test
def testShouldProcessPausableNotPaused(): Unit \ Assert =
    Assert.assertTrue(ProcessMode.shouldProcess(false, ProcessMode.Pausable))

@Test
def testShouldProcessPausablePaused(): Unit \ Assert =
    Assert.assertFalse(ProcessMode.shouldProcess(true, ProcessMode.Pausable))

@Test
def testShouldProcessWhenPausedNotPaused(): Unit \ Assert =
    Assert.assertFalse(ProcessMode.shouldProcess(false, ProcessMode.WhenPaused))

@Test
def testShouldProcessWhenPausedPaused(): Unit \ Assert =
    Assert.assertTrue(ProcessMode.shouldProcess(true, ProcessMode.WhenPaused))

@Test
def testShouldProcessAlwaysNotPaused(): Unit \ Assert =
    Assert.assertTrue(ProcessMode.shouldProcess(false, ProcessMode.Always))

@Test
def testShouldProcessAlwaysPaused(): Unit \ Assert =
    Assert.assertTrue(ProcessMode.shouldProcess(true, ProcessMode.Always))

@Test
def testShouldProcessDisabledNotPaused(): Unit \ Assert =
    Assert.assertFalse(ProcessMode.shouldProcess(false, ProcessMode.Disabled))

@Test
def testShouldProcessDisabledPaused(): Unit \ Assert =
    Assert.assertFalse(ProcessMode.shouldProcess(true, ProcessMode.Disabled))
