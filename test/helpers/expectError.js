const expectError = async promise => {
  try {
    await promise
  } catch (error) {
    return
  }

  assert(false, 'Expected error')
}

module.exports = expectError
