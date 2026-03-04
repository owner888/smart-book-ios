module.exports = {
  onload() {
    return true;
  },

  async getClientIP() {
    const response = await fetch('https://json.nipp.cc/');
    if (!response.ok) {
      throw new Error(`fetch failed: ${response.status}`);
    }
    return await response.json();
  }
};
