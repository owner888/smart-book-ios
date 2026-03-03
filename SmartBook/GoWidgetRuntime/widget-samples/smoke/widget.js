module.exports = {
  onload() {
    return true;
  },
  ping(value) {
    return `pong:${value ?? 'ok'}`;
  }
};
