#!/usr/bin/env node
/* eslint-disable no-console */
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

function usage() {
  console.log(`Usage: agent-automation-install [targetDir] [--force] [--update] [--dry-run] [--check]\n\nExamples:\n  agent-automation-install .\n  agent-automation-install ../other-repo --force\n  agent-automation-update ../other-repo\n  agent-automation-update ../other-repo --check\n\nModes:\n- default install: copy missing files, keep existing files\n- --update: overwrite only files previously installed and still unchanged\n- --force: overwrite all managed files\n- --dry-run: report planned changes without writing files\n- --check: exit non-zero when updates/conflicts are detected`);
}

function parseArgs(argv, invokedAs) {
  let targetDir = process.cwd();
  let force = false;
  let update = invokedAs === 'agent-automation-update';
  let dryRun = false;
  let check = false;

  for (const arg of argv) {
    if (arg === '--help' || arg === '-h') {
      usage();
      process.exit(0);
    } else if (arg === '--force') {
      force = true;
    } else if (arg === '--update') {
      update = true;
    } else if (arg === '--dry-run') {
      dryRun = true;
    } else if (arg === '--check') {
      check = true;
    } else if (arg.startsWith('-')) {
      throw new Error(`Unknown flag: ${arg}`);
    } else {
      targetDir = path.resolve(arg);
    }
  }

  return { targetDir, force, update, dryRun, check };
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function hashFile(filePath) {
  const data = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(data).digest('hex');
}

function loadPackageMeta(packageRoot) {
  const pkgPath = path.join(packageRoot, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  return { name: pkg.name, version: pkg.version };
}

function getStatePath(targetDir) {
  return path.join(targetDir, '.agent-automation', 'state.json');
}

function loadState(targetDir) {
  const statePath = getStatePath(targetDir);
  if (!fs.existsSync(statePath)) {
    return { schemaVersion: 1, packageName: null, packageVersion: null, files: {} };
  }

  try {
    const parsed = JSON.parse(fs.readFileSync(statePath, 'utf8'));
    return {
      schemaVersion: typeof parsed.schemaVersion === 'number' ? parsed.schemaVersion : 1,
      packageName: parsed.packageName || null,
      packageVersion: parsed.packageVersion || null,
      files: parsed.files || {}
    };
  } catch {
    return { schemaVersion: 1, packageName: null, packageVersion: null, files: {} };
  }
}

function walkFiles(rootDir) {
  const out = [];

  function visit(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const full = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        visit(full);
      } else {
        out.push(full);
      }
    }
  }

  visit(rootDir);
  return out;
}

function copyManagedFiles({ templateDir, targetDir, force, update, dryRun, previousState }) {
  const templateFiles = walkFiles(templateDir);
  let copied = 0;
  let skipped = 0;
  let conflicts = 0;

  for (const srcPath of templateFiles) {
    const relPath = path.relative(templateDir, srcPath);
    const dstPath = path.join(targetDir, relPath);
    const srcHash = hashFile(srcPath);

    ensureDir(path.dirname(dstPath));

    if (!fs.existsSync(dstPath)) {
      if (!dryRun) {
        fs.copyFileSync(srcPath, dstPath);
      }
      console.log(`[${dryRun ? 'PLAN COPY' : 'COPY'}] ${relPath}`);
      copied += 1;
      continue;
    }

    if (force) {
      if (!dryRun) {
        fs.copyFileSync(srcPath, dstPath);
      }
      console.log(`[${dryRun ? 'PLAN OVERWRITE' : 'OVERWRITE'}] ${relPath}`);
      copied += 1;
      continue;
    }

    if (!update) {
      console.log(`[SKIP] ${relPath} (exists)`);
      skipped += 1;
      continue;
    }

    const previousHash = previousState.files?.[relPath]?.sha256 || null;
    if (!previousHash) {
      console.log(`[SKIP] ${relPath} (not previously managed)`);
      skipped += 1;
      continue;
    }

    const currentHash = hashFile(dstPath);
    if (currentHash !== previousHash) {
      console.log(`[CONFLICT] ${relPath} (locally modified)`);
      conflicts += 1;
      continue;
    }

    if (currentHash === srcHash) {
      console.log(`[UNCHANGED] ${relPath}`);
      skipped += 1;
      continue;
    }

    if (!dryRun) {
      fs.copyFileSync(srcPath, dstPath);
    }
    console.log(`[${dryRun ? 'PLAN UPDATE' : 'UPDATE'}] ${relPath}`);
    copied += 1;
  }

  return { copied, skipped, conflicts };
}

function writeState({ templateDir, targetDir, packageName, packageVersion }) {
  const files = {};
  for (const srcPath of walkFiles(templateDir)) {
    const relPath = path.relative(templateDir, srcPath);
    const dstPath = path.join(targetDir, relPath);
    if (!fs.existsSync(dstPath) || fs.statSync(dstPath).isDirectory()) {
      continue;
    }

    files[relPath] = {
      sha256: hashFile(dstPath)
    };
  }

  const stateDir = path.join(targetDir, '.agent-automation');
  ensureDir(stateDir);
  const statePath = path.join(stateDir, 'state.json');
  const state = {
    schemaVersion: 1,
    packageName,
    packageVersion,
    updatedAt: new Date().toISOString(),
    files
  };

  fs.writeFileSync(statePath, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
}

function setExecutableBits(targetDir) {
  const scriptsDir = path.join(targetDir, 'scripts', 'agents');
  if (!fs.existsSync(scriptsDir)) return;

  for (const file of fs.readdirSync(scriptsDir)) {
    const full = path.join(scriptsDir, file);
    if (!fs.statSync(full).isFile()) continue;
    if (file.endsWith('.sh') || file === 'launch-agent-daemon.py') {
      const currentMode = fs.statSync(full).mode;
      fs.chmodSync(full, currentMode | 0o111);
    }
  }
}

function main() {
  const invokedAs = path.basename(process.argv[1] || '');
  const { targetDir, force, update, dryRun, check } = parseArgs(process.argv.slice(2), invokedAs);
  const packageRoot = path.resolve(__dirname, '..');
  const templateDir = path.join(packageRoot, 'template');
  const { name, version } = loadPackageMeta(packageRoot);

  if (!fs.existsSync(templateDir)) {
    throw new Error(`Template directory not found: ${templateDir}`);
  }

  ensureDir(targetDir);
  const previousState = loadState(targetDir);

  const { copied, skipped, conflicts } = copyManagedFiles({
    templateDir,
    targetDir,
    force,
    update,
    dryRun,
    previousState
  });

  if (!dryRun) {
    setExecutableBits(targetDir);
    writeState({
      templateDir,
      targetDir,
      packageName: name,
      packageVersion: version
    });
  }

  console.log('\n[DONE] Agent automation applied.');
  console.log(`Mode: ${force ? 'force' : update ? 'update' : 'install'}${dryRun ? ' (dry-run)' : ''}`);
  console.log(`Results: copied=${copied} skipped=${skipped} conflicts=${conflicts}`);

  if (conflicts > 0) {
    console.log('Local modifications were preserved. Re-run with --force to overwrite all managed files.');
  }

  if (check) {
    if (copied > 0 || conflicts > 0) {
      console.error('[CHECK] Pending updates or conflicts detected.');
      process.exit(2);
    }
    console.log('[CHECK] No pending updates.');
  }

  if (update && conflicts > 0 && !force) {
    console.error('[FAIL] Update completed with conflicts. Resolve or re-run with --force.');
    process.exit(3);
  }

  console.log('Next steps:');
  console.log('1) Initialize project context: scripts/agents/init-project-context.sh');
  console.log('2) Review docs/agent-project-alignment.md and complete any remaining project-specific fields.');
  console.log('3) Validate scripts with: bash -n scripts/agents/*.sh && python3 -m py_compile scripts/agents/launch-agent-daemon.py');
}

main();
