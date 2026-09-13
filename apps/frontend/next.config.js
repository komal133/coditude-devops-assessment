/** @type {import('next').NextConfig} */
const nextConfig = {
  // "standalone" produces a self-contained .next/standalone folder.
  // It is what makes both the Docker image small AND the plain EC2
  // (non-containerised) deployment possible with a single node command.
  output: 'standalone',
};

module.exports = nextConfig;
