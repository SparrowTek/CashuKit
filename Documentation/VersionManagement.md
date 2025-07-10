# Version Management Strategy

## Overview

CashuKit follows semantic versioning (SemVer) for clear and predictable version management. This document outlines our versioning strategy, release process, and migration guidelines.

## Semantic Versioning

We use semantic versioning in the format: `MAJOR.MINOR.PATCH`

### Version Components

- **MAJOR**: Incremented for incompatible API changes
- **MINOR**: Incremented for backwards-compatible functionality additions
- **PATCH**: Incremented for backwards-compatible bug fixes

### Version Examples

- `1.0.0` - Initial stable release
- `1.1.0` - New features, backwards compatible
- `1.1.1` - Bug fixes, backwards compatible
- `2.0.0` - Breaking changes, incompatible with 1.x

## Release Strategy

### Release Types

#### 1. Major Releases (x.0.0)
- **Frequency**: 6-12 months
- **Content**: Breaking changes, major new features, architecture changes
- **Support**: Previous major version supported for 6 months
- **Migration**: Comprehensive migration guide provided

#### 2. Minor Releases (x.y.0)
- **Frequency**: 2-3 months
- **Content**: New features, enhancements, new NUT implementations
- **Support**: All minor versions within major version supported
- **Migration**: No migration required

#### 3. Patch Releases (x.y.z)
- **Frequency**: As needed (weekly/monthly)
- **Content**: Bug fixes, security updates, performance improvements
- **Support**: Latest patch version recommended
- **Migration**: No migration required

### Pre-release Versions

For testing and early adoption:
- **Alpha**: `1.0.0-alpha.1` - Early development, unstable
- **Beta**: `1.0.0-beta.1` - Feature-complete, testing phase
- **Release Candidate**: `1.0.0-rc.1` - Stable, final testing

## Version Lifecycle

### Development Phase
- Version: `x.y.z-dev`
- Branch: `develop`
- Stability: Unstable
- Testing: Continuous integration

### Pre-release Phase
- Version: `x.y.z-alpha/beta/rc.n`
- Branch: `release/x.y.z`
- Stability: Testing
- Testing: Comprehensive testing

### Release Phase
- Version: `x.y.z`
- Branch: `main`
- Stability: Stable
- Testing: Full test suite passed

### Maintenance Phase
- Version: `x.y.z+1`
- Branch: `main`
- Stability: Stable
- Testing: Regression testing

## Branching Strategy

### Main Branches
- `main` - Production-ready code
- `develop` - Integration branch for features

### Supporting Branches
- `feature/*` - Feature development
- `release/*` - Release preparation
- `hotfix/*` - Emergency fixes

### Branch Lifecycle
1. Feature development: `feature/new-feature`
2. Integration: Merge to `develop`
3. Release preparation: `release/x.y.z`
4. Release: Merge to `main` and tag
5. Hotfixes: `hotfix/x.y.z+1`

## API Compatibility

### Backward Compatibility Promise
- **Minor versions**: No breaking changes to public API
- **Patch versions**: No breaking changes to any API
- **Major versions**: May include breaking changes

### Deprecation Policy
1. **Announcement**: Deprecation announced in minor release
2. **Warning**: Deprecation warnings in next minor release
3. **Removal**: Deprecated APIs removed in next major release

### API Stability Levels
- **Public API**: Stable, follows SemVer
- **Internal API**: May change without notice
- **Experimental API**: Marked as experimental, may change

## Migration Guidelines

### Breaking Changes
When introducing breaking changes:
1. Document all breaking changes
2. Provide migration guide
3. Offer automated migration tools where possible
4. Maintain compatibility layer when feasible

### Migration Process
1. **Identify**: Review breaking changes
2. **Plan**: Create migration timeline
3. **Update**: Modify code according to guide
4. **Test**: Verify functionality
5. **Deploy**: Update to new version

## Version Tags

### Git Tags
- Format: `v1.0.0`
- Signed: Yes (for releases)
- Annotated: Yes (with release notes)

### Swift Package Manager
- Uses git tags for version resolution
- Supports semantic versioning ranges
- Automatic dependency resolution

## Release Process

### 1. Preparation
- [ ] Update version number in relevant files
- [ ] Update CHANGELOG.md
- [ ] Run full test suite
- [ ] Update documentation

### 2. Testing
- [ ] Integration tests pass
- [ ] Example projects build successfully
- [ ] Performance benchmarks meet targets
- [ ] Security review completed

### 3. Release
- [ ] Create release branch
- [ ] Final testing on release branch
- [ ] Merge to main
- [ ] Create and push version tag
- [ ] Publish release notes

### 4. Post-release
- [ ] Update package registries
- [ ] Update documentation sites
- [ ] Notify community
- [ ] Monitor for issues

## Version History

### v1.0.0 (Initial Release)
- Complete NUT-00 through NUT-06 implementation
- Core wallet functionality
- SwiftUI integration
- Comprehensive testing

### v1.1.0 (Feature Release)
- Enhanced denomination management
- Real-time balance updates
- Performance improvements
- Additional utility methods

### v1.1.1 (Patch Release)
- Bug fixes in token serialization
- Memory leak fixes
- Documentation updates

### v2.0.0 (Major Release)
- Swift 6.0 compatibility
- Actor-based concurrency model
- Breaking API changes
- New authentication system

## Deprecation Examples

### Deprecation Notice
```swift
@available(*, deprecated, renamed: "newMethodName")
func oldMethodName() {
    // Implementation
}
```

### Availability Annotations
```swift
@available(iOS 17.0, macOS 14.0, *)
func newFeature() {
    // New feature implementation
}
```

## Version Compatibility Matrix

| CashuKit Version | iOS  | macOS | tvOS | watchOS | visionOS |
|------------------|------|-------|------|---------|----------|
| 1.0.x            | 17+  | 14+   | 17+  | 10+     | 2+       |
| 1.1.x            | 17+  | 14+   | 17+  | 10+     | 2+       |
| 2.0.x            | 17+  | 14+   | 17+  | 10+     | 2+       |

## Dependency Management

### Core Dependencies
- **swift-secp256k1**: Cryptographic operations
- Version pinning strategy: `from: "x.y.z"`
- Regular dependency updates

### Dependency Updates
- Monthly security update checks
- Quarterly dependency version reviews
- Major dependency updates with major releases

## Security Updates

### Security Patch Policy
- Critical security issues: Emergency patch release
- Security issues: Next patch release
- All security updates documented

### Security Version Support
- Latest major version: Full security support
- Previous major version: Security patches for 6 months
- Older versions: No security support

## Communication

### Release Announcements
- GitHub Releases with detailed notes
- Documentation updates
- Community notifications

### Breaking Changes Communication
- Advance notice in prior minor releases
- Comprehensive migration guides
- Community discussion period

## Tooling

### Version Management Tools
- Semantic release automation
- Changelog generation
- Version bumping scripts

### Quality Assurance
- Automated version compatibility checks
- Release validation pipeline
- Performance regression testing

## Support Policy

### Long-term Support (LTS)
- Major versions have 12-month support
- Security updates for 6 months after new major release
- Bug fixes for current major version only

### End-of-Life Process
1. **Announcement**: 6 months before EOL
2. **Warning**: 3 months before EOL
3. **End-of-Life**: No further updates

## Best Practices

### For Maintainers
- Always update CHANGELOG.md
- Test thoroughly before release
- Document breaking changes clearly
- Maintain release notes quality

### For Users
- Pin to specific minor versions for stability
- Test pre-release versions
- Follow migration guides carefully
- Keep dependencies updated

## FAQ

### Q: How often should I update CashuKit?
A: Update to latest patch versions immediately, minor versions quarterly, major versions with planning.

### Q: What if I need a feature from a newer version?
A: Evaluate upgrade path, consider backporting for critical features, or use feature flags.

### Q: How do I handle breaking changes?
A: Follow migration guide, test thoroughly, consider gradual rollout.

### Q: What's the policy on experimental features?
A: Experimental features may change without notice, use at your own risk in production.

---

This version management strategy ensures predictable, stable releases while allowing for innovation and improvement in CashuKit.