# Contributing to Flutter Fixtures

Thank you for your interest in contributing to Flutter Fixtures! This document provides guidelines and information for contributors.

## 🎯 Project Overview

Flutter Fixtures is a universal data mocking library for Flutter that works with any data source - HTTP APIs, databases, file systems, GraphQL endpoints, and more. The library is designed to be modular, extensible, and easy to use.

## 📦 Project Structure

The project is organized as a Flutter workspace with multiple packages:

- **`packages/flutter_fixtures_core`**: Core interfaces and domain models
- **`packages/flutter_fixtures_dio`**: Dio HTTP client implementation  
- **`packages/flutter_fixtures_ui`**: UI components for fixture selection
- **`packages/flutter_fixtures`**: Meta-package combining all components
- **`example/`**: Example application demonstrating usage

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (comes with Flutter)
- Git

### Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/brotoo25/flutter_fixtures.git
   cd flutter_fixtures
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Run tests to ensure everything works**
   ```bash
   flutter test
   ```

4. **Run the example app**
   ```bash
   cd example
   flutter run
   ```

## 🛠️ Development Workflow

### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the existing code style and patterns
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   # Run all tests
   flutter test
   
   # Run analysis
   flutter analyze
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

### Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `test:` - Adding or updating tests
- `refactor:` - Code refactoring
- `style:` - Code style changes (formatting, etc.)
- `chore:` - Maintenance tasks

Examples:
```
feat: add GraphQL data provider support
fix: handle null values in fixture selection
docs: update README with new examples
test: add unit tests for FixtureSelector mixin
```

## 🧪 Testing Guidelines

### Writing Tests

- **Unit tests**: Test individual classes and methods
- **Integration tests**: Test component interactions
- **Example tests**: Ensure examples work correctly

### Test Structure

```dart
void main() {
  group('ClassName', () {
    late ClassName instance;
    
    setUp(() {
      instance = ClassName();
    });
    
    group('methodName', () {
      test('should do something when condition', () {
        // Arrange
        // Act  
        // Assert
      });
    });
  });
}
```

### Running Tests

```bash
# All tests
flutter test

# Specific package
flutter test packages/flutter_fixtures_core

# With coverage
flutter test --coverage
```

## 📝 Documentation Guidelines

### Code Documentation

- Use clear, descriptive comments
- Document public APIs with dartdoc comments
- Include examples in documentation when helpful

```dart
/// Creates a fixture interceptor for Dio HTTP client.
///
/// The [dataQuery] is used to load and parse fixture files.
/// The [dataSelector] determines how fixtures are selected.
///
/// Example:
/// ```dart
/// final interceptor = FixturesInterceptor(
///   dataQuery: DioDataQuery(),
///   dataSelector: DataSelectorType.random(),
/// );
/// ```
class FixturesInterceptor {
  // Implementation
}
```

### README Updates

- Keep package-specific READMEs focused on their functionality
- Update the main README for significant changes
- Include practical examples
- Add troubleshooting information when relevant

## 🎨 Code Style

### Dart Style Guide

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format` to format code
- Run `flutter analyze` to check for issues

### Package Organization

- Keep packages focused on single responsibilities
- Use clear, descriptive names for classes and methods
- Follow existing patterns and conventions
- Maintain backward compatibility when possible

## 🐛 Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Description**: Clear description of the issue
2. **Steps to reproduce**: Minimal steps to reproduce the problem
3. **Expected behavior**: What you expected to happen
4. **Actual behavior**: What actually happened
5. **Environment**: Flutter version, platform, etc.
6. **Code sample**: Minimal code that demonstrates the issue

### Feature Requests

For feature requests, please include:

1. **Use case**: Why is this feature needed?
2. **Proposed solution**: How should it work?
3. **Alternatives**: Any alternative solutions considered?
4. **Examples**: Code examples of how it would be used

## 🔄 Pull Request Process

### Before Submitting

- [ ] Tests pass (`flutter test`)
- [ ] Code analysis passes (`flutter analyze`)
- [ ] Documentation is updated
- [ ] Examples work correctly
- [ ] Commit messages follow convention

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (please describe)

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests pass
- [ ] No breaking changes (or clearly documented)
```

### Review Process

1. **Automated checks**: CI will run tests and analysis
2. **Code review**: Maintainers will review your changes
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, your PR will be merged

## 🏗️ Architecture Guidelines

### Adding New Data Providers

When adding support for new data sources:

1. **Implement DataQuery interface**
2. **Use FixtureSelector mixin for selection logic**
3. **Add comprehensive tests**
4. **Update documentation with examples**
5. **Consider creating a separate package**

### Adding UI Components

For new UI components:

1. **Implement DataSelectorView interface**
2. **Follow Material Design guidelines**
3. **Support theming and customization**
4. **Add to flutter_fixtures_ui package**
5. **Include usage examples**

## 🤝 Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Maintain a welcoming environment

### Getting Help

- **Issues**: Use GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub discussions for questions and ideas
- **Documentation**: Check existing documentation first

## 📋 Release Process

Releases are handled by maintainers following semantic versioning:

- **Patch** (x.x.1): Bug fixes
- **Minor** (x.1.x): New features (backward compatible)
- **Major** (1.x.x): Breaking changes

## 🙏 Recognition

Contributors will be recognized in:

- GitHub contributors list
- Release notes for significant contributions
- Documentation acknowledgments

Thank you for contributing to Flutter Fixtures! 🎉
