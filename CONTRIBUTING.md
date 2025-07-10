# Contributing to CashuKit

Thank you for your interest in contributing to CashuKit! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Release Process](#release-process)
- [Community](#community)

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

### Our Standards

- **Be respectful**: Treat everyone with respect and kindness
- **Be inclusive**: Welcome contributors from all backgrounds
- **Be constructive**: Provide helpful feedback and suggestions
- **Be patient**: Understand that everyone has different skill levels
- **Be collaborative**: Work together towards common goals

## Getting Started

### Prerequisites

- Xcode 15.0+ with Swift 6.0+
- macOS 14.0+ for development
- Git for version control
- SwiftLint for code quality

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/your-username/CashuKit.git
   cd CashuKit
   ```

2. **Set up upstream remote**
   ```bash
   git remote add upstream https://github.com/original-repo/CashuKit.git
   ```

3. **Install dependencies**
   ```bash
   swift package resolve
   ```

4. **Verify setup**
   ```bash
   swift build
   swift test
   ```

### Project Structure

```
CashuKit/
├── Sources/CashuKit/           # Main library code
│   ├── Core/                   # Core utilities and base classes
│   ├── Models/                 # Data models and types
│   ├── NUTs/                   # NUT implementations
│   ├── Networking/             # Network layer
│   ├── Services/               # Business logic services
│   └── Utils/                  # Utility functions
├── Tests/CashuKitTests/        # Test files
├── Examples/                   # Example implementations
├── Documentation/              # Documentation files
└── .github/                    # CI/CD and GitHub configuration
```

## Development Workflow

### Branching Strategy

- `main`: Production-ready code
- `develop`: Integration branch for features
- `feature/*`: Feature development branches
- `hotfix/*`: Emergency fixes
- `release/*`: Release preparation

### Feature Development

1. **Create feature branch**
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write code following our coding standards
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   swift test
   swift build
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create pull request**
   - Open a PR from your feature branch to `develop`
   - Fill out the PR template completely
   - Link any related issues

### Commit Message Convention

We use conventional commits for clear release notes:

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Build process or auxiliary tool changes

Examples:
```
feat: add real-time balance updates
fix: resolve token serialization issue
docs: update API documentation
test: add integration tests for minting
```

## Coding Standards

### Swift Style Guide

We follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/) and use SwiftLint for enforcement.

### Key Principles

1. **Clarity**: Code should be self-documenting
2. **Type Safety**: Leverage Swift's type system
3. **Actor Model**: Use actors for thread safety
4. **Error Handling**: Use structured error handling
5. **Performance**: Write efficient, optimized code

### Code Quality

- **SwiftLint**: All code must pass SwiftLint checks
- **Documentation**: Public APIs must be documented
- **Testing**: New features require tests
- **Security**: Follow security best practices

### Example Code Style

```swift
/// A service that manages Cashu token operations
public actor TokenService {
    
    // MARK: - Properties
    
    private let networkManager: NetworkManager
    private var activeTokens: [String: CashuToken] = [:]
    
    // MARK: - Initialization
    
    /// Initialize the token service
    /// - Parameter networkManager: Network manager for API calls
    public init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // MARK: - Public Methods
    
    /// Create a new token with the specified amount
    /// - Parameters:
    ///   - amount: Token amount in base units
    ///   - memo: Optional memo for the token
    /// - Returns: The created token
    /// - Throws: `TokenError` if creation fails
    public func createToken(
        amount: Int,
        memo: String? = nil
    ) async throws -> CashuToken {
        guard amount > 0 else {
            throw TokenError.invalidAmount
        }
        
        // Implementation
    }
}
```

## Testing

### Test Requirements

- **Unit Tests**: Test individual components
- **Integration Tests**: Test component interactions
- **Performance Tests**: Verify performance requirements
- **Security Tests**: Validate security measures

### Test Structure

```swift
import Testing
@testable import CashuKit

struct TokenServiceTests {
    
    @Test("Token creation with valid amount")
    func testTokenCreation() async throws {
        // Given
        let service = TokenService(networkManager: MockNetworkManager())
        let amount = 1000
        
        // When
        let token = try await service.createToken(amount: amount)
        
        // Then
        #expect(token.amount == amount)
    }
    
    @Test("Token creation with invalid amount throws error")
    func testTokenCreationInvalidAmount() async {
        // Given
        let service = TokenService(networkManager: MockNetworkManager())
        
        // When/Then
        await #expect(throws: TokenError.invalidAmount) {
            try await service.createToken(amount: -1)
        }
    }
}
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter TokenServiceTests

# Run with coverage
swift test --enable-code-coverage
```

## Documentation

### Documentation Requirements

- **Public APIs**: Must be documented with DocC
- **README**: Keep updated with new features
- **Examples**: Provide usage examples
- **Migration Guides**: Document breaking changes

### DocC Documentation

```swift
/// Creates a new Cashu token
///
/// This method creates a new token with the specified amount and optional memo.
/// The token can be used for transfers between wallets.
///
/// ```swift
/// let token = try await service.createToken(amount: 1000, memo: "Payment")
/// ```
///
/// - Parameters:
///   - amount: The token amount in base units
///   - memo: Optional memo to attach to the token
/// - Returns: A new `CashuToken` instance
/// - Throws: `TokenError.invalidAmount` if amount is invalid
public func createToken(amount: Int, memo: String? = nil) async throws -> CashuToken
```

## Pull Request Process

### Before Submitting

1. **Update from develop**
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout feature/your-feature
   git rebase develop
   ```

2. **Run quality checks**
   ```bash
   swift test
   swiftlint
   swift build -c release
   ```

3. **Update documentation**
   - Update README if needed
   - Add/update API documentation
   - Update CHANGELOG.md

### PR Template

When creating a PR, include:

- **Description**: What does this PR do?
- **Related Issues**: Link to related issues
- **Testing**: How was this tested?
- **Breaking Changes**: Any breaking changes?
- **Checklist**: Complete the provided checklist

### Review Process

1. **Automated Checks**: CI must pass
2. **Code Review**: At least one approval required
3. **Testing**: All tests must pass
4. **Documentation**: Documentation must be updated

## Release Process

### Version Management

We use semantic versioning (SemVer):
- **Major**: Breaking changes
- **Minor**: New features, backwards compatible
- **Patch**: Bug fixes, backwards compatible

### Release Steps

1. **Prepare Release**
   - Update version numbers
   - Update CHANGELOG.md
   - Update documentation

2. **Create Release PR**
   - From `develop` to `main`
   - Title: `chore: prepare release vX.Y.Z`

3. **Tag Release**
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

4. **Post-Release**
   - Update package registries
   - Announce release
   - Update documentation sites

## Community

### Communication

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community chat
- **Pull Requests**: Code contributions and reviews

### Getting Help

- Check existing issues and discussions
- Read the documentation
- Look at examples
- Ask questions in discussions

### Reporting Issues

When reporting bugs:

1. **Search existing issues** first
2. **Use issue template** provided
3. **Include reproduction steps**
4. **Provide system information**
5. **Add relevant logs/screenshots**

### Feature Requests

For new features:

1. **Check existing requests** first
2. **Use feature request template**
3. **Explain the use case**
4. **Provide implementation ideas**
5. **Consider backwards compatibility**

## Recognition

Contributors are recognized in:
- README.md contributors section
- Release notes
- GitHub contributors graph

## Questions?

If you have questions about contributing:
- Open a GitHub Discussion
- Check the documentation
- Look at existing issues and PRs

Thank you for contributing to CashuKit! 🚀