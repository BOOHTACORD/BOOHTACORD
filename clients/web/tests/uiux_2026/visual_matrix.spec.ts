import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { ux2026ReferenceViewports, ux2026RequiredViewports, ux2026ShellViewports } from './viewport_matrix'

type MatrixEntry = {
  id: string
  surface: 'desktop' | 'mobile'
  referenceAsset: string
  referenceStatus: 'PRESENT_IN_ARCHIVE'
  targetViewport: { width: number; height: number }
  referenceRasterPx: { width: number; height: number }
  fixture: string
  testFile: string
  flutterTestFile: string
  interaction: string
  expectedOrException: string
  owner: string
  sourceComparisonStatus?: string
}

type VisualMatrix = {
  issue: string
  expectedCount: number
  sourceArchive: string
  sourceArchiveSha256: string
  sourceArchiveStatus: string
  sourceIntegrityFindings: Array<{
    asset: string
    duplicateOf: string
    sha256: string
    status: string
  }>
  sourceReviewEvidence: {
    status: string
    sourceRevision: string
    reviewedScreenIds: string[]
    mobile393ReportSha256: string
    desktop1440ReportSha256: string
    dataset: { members: number; categories: number; channels: number; auditRows: number }
  }
  supplementalSourceReviewEvidence: {
    status: string
    screenId: string
    report: string
    capture: string
    captureSha256: string
    rasterPx: [number, number]
    sourceRevision: string
    reviewNote: string
  }
  settingsCaptureReviewEvidence: {
    status: string
    sourceRevision: string
    report: string
    reviewedScreenIds: string[]
    reviewNotes: Record<string, string>
  }
  screenShareQualityReviewEvidence: {
    status: string
    sourceRevision: string
    report: string
    captures: Array<{
      screenId: string
      state: string
      path: string
      sha256: string
      rasterPx: [number, number]
    }>
  }
  screens: MatrixEntry[]
}

const repoRoot = resolve(fileURLToPath(new URL('../../../..', import.meta.url)))
const matrixPath = new URL('./visual_matrix.json', import.meta.url)

describe('UIUX-2026 visual regression inventory', () => {
  it('runs the required viewport matrix and captures each required target size', () => {
    const shellViewports = new Set(ux2026ShellViewports.map(({ width, height }) => `${width}x${height}`))
    const screenshotViewports = new Set(ux2026RequiredViewports.map(({ width, height }) => `${width}x${height}`))
    const sourceViewports = new Set(ux2026ReferenceViewports.map(({ width, height }) => `${width}x${height}`))

    expect([...screenshotViewports]).toEqual(['320x640', '390x844', '768x1024', '1024x768', '1440x900', '1920x1080'])
    expect([...sourceViewports]).toEqual(['1440x900', '393x852'])
    for (const viewport of [...screenshotViewports, ...sourceViewports]) expect(shellViewports.has(viewport), `${viewport} is swept`).toBe(true)
  })

  it('catalogues all 41 desktop and mobile reference slots', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix

    expect(matrix.issue).toBe('Egkurilov/BOOHTACORD#289')
    expect(matrix.sourceArchiveStatus).toContain('41 PNG entries verified when the ignored archive is supplied')
    expect(matrix.sourceArchiveStatus).toContain('not tracked in clean checkouts')
    expect(matrix.expectedCount).toBe(41)
    expect(matrix.screens).toHaveLength(41)
    expect(matrix.screens.filter(({ surface }) => surface === 'desktop')).toHaveLength(18)
    expect(matrix.screens.filter(({ surface }) => surface === 'mobile')).toHaveLength(23)
    expect(matrix.screens.every(({ referenceAsset }) => referenceAsset.length > 0)).toBe(true)
    expect(new Set(matrix.screens.map(({ id }) => id)).size).toBe(41)
    expect(new Set(matrix.screens.map(({ referenceAsset }) => referenceAsset)).size).toBe(41)

    expect(matrix.sourceArchive).toBe('artifacts/ui-ux-screenshots.zip')
  })

  it('maps each slot to an existing test surface, viewport, expected result, and owner', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix

    for (const entry of matrix.screens) {
      expect(entry.id).toMatch(/^(D|M)\d{2}$/)
      expect(entry.fixture.length, `${entry.id} fixture`).toBeGreaterThan(0)
      expect(entry.testFile.length, `${entry.id} test file`).toBeGreaterThan(0)
      expect(entry.flutterTestFile.length, `${entry.id} Flutter test file`).toBeGreaterThan(0)
      expect(entry.interaction.length, `${entry.id} interaction`).toBeGreaterThan(0)
      expect(entry.expectedOrException.length, `${entry.id} expected result`).toBeGreaterThan(0)
      expect(entry.owner.length, `${entry.id} owner`).toBeGreaterThan(0)
      expect(existsSync(resolve(repoRoot, entry.fixture)), `${entry.id} fixture exists`).toBe(true)
      expect(existsSync(resolve(repoRoot, entry.testFile)), `${entry.id} test file exists`).toBe(true)
      expect(existsSync(resolve(repoRoot, entry.flutterTestFile)), `${entry.id} Flutter test file exists`).toBe(true)
      expect(entry.targetViewport.width).toBeGreaterThan(0)
      expect(entry.targetViewport.height).toBeGreaterThan(0)
      expect(entry.targetViewport).toEqual(entry.surface === 'desktop'
        ? { width: 1440, height: 900 }
        : { width: 393, height: 852 })
      expect(entry.referenceRasterPx).toEqual(entry.surface === 'desktop'
        ? { width: 2880, height: 1800 }
        : entry.referenceAsset.includes('stream-launch')
          ? { width: 786, height: 1704 }
          : { width: 1179, height: 2556 })

      expect(entry.referenceAsset).toMatch(/^(desktop|mobile)-.+\.png$/)
      expect(entry.referenceStatus).toBe('PRESENT_IN_ARCHIVE')
    }
  })

  it('maps guild settings to the admin settings flow and marks the duplicated desktop source', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const desktop = matrix.screens.find(({ referenceAsset }) => referenceAsset === 'desktop-guild-settings.png')!
    const mobile = matrix.screens.find(({ referenceAsset }) => referenceAsset === 'mobile-guild-settings.png')!

    expect(matrix.sourceIntegrityFindings).toEqual([{
      asset: 'desktop-guild-settings.png',
      duplicateOf: 'desktop-guild-members.png',
      sha256: '0a0ba90ad3288815fa4925b540396e74defaf463f4542fe38c6370c5ff57ff57',
      status: 'BLOCKED_DUPLICATE_BASELINE',
    }])
    for (const entry of [desktop, mobile]) {
      expect(entry.fixture).toBe('clients/web/tests/guild_lifecycle/fixture.html')
      expect(entry.testFile).toBe('clients/web/tests/guild_lifecycle/guild.browser.spec.ts')
      expect(entry.owner).toBe('clients/web/src/admin/guild_settings/AdminGuildSettings.vue')
      expect(entry.flutterTestFile).toBe('clients/flutter/test/admin_guild_settings_test.dart')
      expect(entry.interaction).toContain('Настройки гильдии')
    }
    expect(desktop.sourceComparisonStatus).toBe('BLOCKED_DUPLICATE_BASELINE')
    expect(desktop.expectedOrException).toContain('desktop-guild-members.png')
  })

  it('records reviewed full-stack admin captures without treating them as approved goldens', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const reviewedAdminIds = new Set([
      'D05', 'D06', 'D07', 'D08', 'D09', 'D10',
      'M08', 'M09', 'M10', 'M11', 'M12', 'M13',
    ])

    for (const entry of matrix.screens.filter(({ id }) => reviewedAdminIds.has(id))) {
      expect(entry.sourceComparisonStatus, `${entry.id} capture review`).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
    }

    expect(matrix.sourceReviewEvidence).toMatchObject({
      status: 'REVIEWED_RUNTIME_CAPTURES_NOT_APPROVED_GOLDENS',
      sourceRevision: '55f18d2b179ab87f93a9cb1d08ed9b3fffff338c',
      reviewedScreenIds: [...reviewedAdminIds].sort(),
      mobile393ReportSha256: expect.stringMatching(/^[a-f0-9]{64}$/),
      desktop1440ReportSha256: expect.stringMatching(/^[a-f0-9]{64}$/),
      dataset: { members: 20, categories: 3, channels: 8, auditRows: 100 },
    })

    const settings = matrix.screens.find(({ id }) => id === 'D11')!
    expect(settings.sourceComparisonStatus).toBe('BLOCKED_DUPLICATE_BASELINE')
    expect(matrix.screens.filter(({ id, sourceComparisonStatus }) =>
      reviewedAdminIds.has(id) && sourceComparisonStatus === 'REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN'))
      .toHaveLength(reviewedAdminIds.size)
  })

  it('maps M07 to full-app global search and records review-only source evidence', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const search = matrix.screens.find(({ id }) => id === 'M07')!

    expect(search.fixture).toBe('tools/qa/client_lifecycle/run.py')
    expect(search.testFile).toBe('tools/qa/client_lifecycle/scenario.mjs')
    expect(search.interaction).toContain('global workspace search')
    expect(search.owner).toContain('clients/web/src/workspace/search/WorkspaceSearchPanel.vue')
    expect(search.owner).toContain('clients/web/src/search/SearchPanel.vue')
    expect(search.sourceComparisonStatus).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
    expect(matrix.supplementalSourceReviewEvidence).toMatchObject({
      status: 'REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN',
      screenId: 'M07',
      report: 'evidence/qa/qa294-dm-live-full-app-2026-10-10.json',
      capture: '.out/client-lifecycle/393/global-search.png',
      captureSha256: expect.stringMatching(/^[a-f0-9]{64}$/),
      rasterPx: [1179, 2556],
      sourceRevision: expect.stringMatching(/^[a-f0-9]{40}$/),
      reviewNote: expect.stringContaining('focus'),
    })
  })

  it('records visually reviewed full-stack DM captures without approving pixel goldens', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const evidence = JSON.parse(readFileSync(resolve(repoRoot, 'evidence/qa/qa294-dm-live-full-app-2026-10-10.json'), 'utf8'))
    const expectedReviews = [
      { id: 'D04', note: 'synthetic account and message data' },
      { id: 'M04', note: 'one synthetic account while the source lists six users' },
      { id: 'M05', note: 'synthetic account header' },
      { id: 'M06', note: 'sixth reaction wraps to a second row' },
      { id: 'M07', note: 'keyboard focus ring' },
    ]
    const captures = evidence.current_branch_revalidation.source_matched_captures

    for (const review of expectedReviews) {
      const screen = matrix.screens.find(({ id }) => id === review.id)!
      const capture = captures.find(({ catalog_slot }: { catalog_slot: string }) => catalog_slot === review.id)!

      expect(screen.sourceComparisonStatus, `${review.id} matrix review`).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
      expect(screen.expectedOrException.toLowerCase(), `${review.id} observation`).toContain(review.note)
      expect(capture.review_status, `${review.id} capture review`).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
      expect(capture.source.raster).toBe(capture.after.raster)
      expect(capture.source.sha256).toMatch(/^[a-f0-9]{64}$/)
      expect(capture.after.sha256).toMatch(/^[a-f0-9]{64}$/)
    }

    expect(evidence.current_branch_revalidation.limitation).toContain('D04 and M04–M07 were visually reviewed')
    expect(evidence.current_branch_revalidation.limitation).not.toContain('were not visually re-reviewed')
  })

  it('records reviewed mobile settings captures and keeps runtime-state differences review-only', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const evidence = JSON.parse(readFileSync(resolve(repoRoot, 'evidence/qa/qa297-personal-settings-2026-10-10.json'), 'utf8'))
    const settingsEvidence = matrix.settingsCaptureReviewEvidence
    const expectedReviews = [
      { id: 'M15', section: 'profile', note: 'synthetic identity' },
      { id: 'M16', section: 'security', note: 'active sessions' },
      { id: 'M17', section: 'audio', note: 'browser device inventory' },
      { id: 'M18', section: 'notifications', note: 'denies permission' },
      { id: 'M19', section: 'about', note: '503 error' },
    ]

    expect(settingsEvidence).toMatchObject({
      status: 'REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN',
      sourceRevision: 'ab12691186a51beae7988dee01021e0ea7b5ef54',
      report: 'evidence/qa/qa297-personal-settings-2026-10-10.json',
      reviewedScreenIds: expectedReviews.map(({ id }) => id),
    })

    for (const review of expectedReviews) {
      const screen = matrix.screens.find(({ id }) => id === review.id)!
      const capture = evidence.comparisons.find(({ section }: { section: string }) => section === review.section)!

      expect(screen.sourceComparisonStatus, `${review.id} matrix review`).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
      expect(settingsEvidence.reviewNotes[review.id], `${review.id} observation`).toContain(review.note)
      expect(capture.visual_review_status, `${review.id} capture status`).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
      expect(capture.visual_review_note, `${review.id} capture note`).toBe(settingsEvidence.reviewNotes[review.id])
      expect(capture.dimensions_match, `${review.id} dimensions`).toBe(true)
      expect(capture.source.raster).toBe('1179x2556')
      expect(capture.after.raster).toBe('1179x2556')
      expect(capture.source.sha256).toMatch(/^[a-f0-9]{64}$/)
      expect(capture.after.sha256).toMatch(/^[a-f0-9]{64}$/)
    }

    expect(settingsEvidence.reviewNotes.M15).toContain('Удалить')
    expect(settingsEvidence.reviewNotes.M15).toContain('only when avatar_url is present')
    expect(settingsEvidence.reviewNotes.M15).not.toContain('parity needs a targeted follow-up')
    expect(settingsEvidence.reviewNotes.M19).toContain('not suitable as a golden')
    expect(evidence.limitations.join(' ')).toContain('browser device inventory')
    expect(evidence.limitations.join(' ')).toContain('HTTP 503')
  })

  it('records current mobile screen-share captures and direct 1440p behavior as review-only', () => {
    const matrix = JSON.parse(readFileSync(matrixPath, 'utf8')) as VisualMatrix
    const report = JSON.parse(readFileSync(resolve(repoRoot, 'evidence/qa/qa320-screen-share-quality-2026-10-10.json'), 'utf8'))
    const review = matrix.screenShareQualityReviewEvidence
    const expectedCaptures = [
      { screenId: 'M20', state: 'default-actions', file: 'mobile-stream-launch-actions-current-393x852-2x.png' },
      { screenId: 'M21', state: 'selected-1440p-30fps', file: 'mobile-stream-launch-settings-1440p-current-393x852-2x.png' },
    ]

    expect(review).toMatchObject({
      status: 'REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN',
      sourceRevision: '562bd3c7',
      report: 'evidence/qa/qa320-screen-share-quality-2026-10-10.json',
    })
    expect(report.latest_visual_regression_after_focus_state_fix.result).toBe('4/4 PASS_AUTOMATED_ONLY')
    expect(report.latest_visual_regression_after_focus_state_fix.confirmed.join(' ')).toContain('1440p remains selected')

    for (const expected of expectedCaptures) {
      const screen = matrix.screens.find(({ id }) => id === expected.screenId)!
      const capture = review.captures.find(({ screenId }) => screenId === expected.screenId)!
      const reportCapture = report.latest_visual_regression_after_focus_state_fix.captures.find(({ state }: { state: string }) => state === expected.state)!

      expect(screen.sourceComparisonStatus).toBe('REVIEWED_CAPTURE_NOT_APPROVED_GOLDEN')
      expect(screen.expectedOrException.toLowerCase()).toContain(expected.screenId === 'M20' ? 'full scenario labels' : '1440p can be selected directly')
      expect(capture.path).toContain(expected.file)
      expect(capture.sha256).toMatch(/^[a-f0-9]{64}$/)
      expect(capture.rasterPx).toEqual([786, 1704])
      expect(reportCapture.capture.path).toBe(capture.path)
      expect(reportCapture.capture.sha256).toBe(capture.sha256)
      expect(reportCapture.capture.raster).toBe('786x1704')
    }
  })
})
