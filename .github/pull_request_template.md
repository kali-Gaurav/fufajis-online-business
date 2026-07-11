## Description
<!-- Brief description of what this PR does -->

## Type of Change
- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 🔒 Security enhancement (fixes security vulnerability)
- [ ] 🔄 Refactor (code improvement, no functional change)
- [ ] 📚 Documentation
- [ ] 🎨 UI/UX improvement
- [ ] ⚡ Performance improvement
- [ ] ♿ Accessibility improvement
- [ ] 🗑️ Deprecation
- [ ] 🔧 Build/CI/Deploy
- [ ] 🔐 Authentication/Authorization

## Related Issues
<!-- Link to related issues using #number -->
Closes #
Related to #

## Checklist - Definition of Done

### Code Quality
- [ ] Code follows project style guide
- [ ] No commented-out code or debug logging
- [ ] No hardcoded secrets, API keys, or credentials
- [ ] Naming is clear and follows conventions
- [ ] Functions are under 50 lines (prefer smaller)
- [ ] No code duplication (DRY principle)
- [ ] No unnecessary dependencies added

### Security
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities  
- [ ] No CSRF vulnerabilities
- [ ] Passwords properly hashed (bcrypt for new auth)
- [ ] No plaintext credentials
- [ ] Input validation implemented
- [ ] Output encoding implemented
- [ ] HTTPS enforced in production
- [ ] RLS/Authorization checks in place

### Testing
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Manual testing completed
- [ ] Edge cases tested
- [ ] Error handling tested
- [ ] Rate limiting tested (if applicable)
- [ ] Offline mode tested (if applicable)

### Documentation
- [ ] README updated (if needed)
- [ ] API documentation updated
- [ ] Environment variables documented
- [ ] Breaking changes documented
- [ ] Migration guide provided (if needed)
- [ ] Comments added for complex logic
- [ ] Inline documentation for public APIs

### Performance
- [ ] No performance regressions
- [ ] Database queries optimized
- [ ] No N+1 query problems
- [ ] Caching implemented (if applicable)
- [ ] Bundle size impact assessed
- [ ] Memory leaks addressed

### Accessibility
- [ ] WCAG 2.1 AA compliant (UI changes)
- [ ] Screen reader tested (UI changes)
- [ ] Keyboard navigation works (UI changes)
- [ ] Color contrast sufficient (UI changes)

## Testing Evidence
<!-- Provide evidence of testing -->

### Unit Tests
```
[Paste test output or describe tests]
```

### Integration Tests
```
[Describe integration testing performed]
```

### Manual Testing
- [ ] Tested on Android
- [ ] Tested on iOS  
- [ ] Tested on Web
- [ ] Tested on different screen sizes
- [ ] Tested with different network conditions
- [ ] Tested in light/dark mode

### Test Cases
1. [Describe test case 1]
2. [Describe test case 2]
3. [Describe test case 3]

## Screenshots (if applicable)
<!-- Add screenshots for UI changes -->

### Before
<!-- Screenshot before change -->

### After
<!-- Screenshot after change -->

## Database Changes (if applicable)
<!-- Describe any database schema changes -->

```sql
-- Migration script (if needed)

```

## Environment Variables (if applicable)
<!-- List any new environment variables required -->

```env
NEW_VAR=value
```

## Breaking Changes
<!-- List any breaking changes -->
- [ ] No breaking changes
- [ ] Breaking changes listed below

### Breaking Changes
1. [Breaking change 1]
2. [Breaking change 2]

## Deployment Notes
<!-- Any special deployment instructions -->

### Pre-deployment
- [ ] Database migration required
- [ ] Feature flag setup needed
- [ ] Environment config updates needed
- [ ] Third-party service integration needed

### Post-deployment
- [ ] Monitor error logs for 1 hour
- [ ] Verify analytics events firing
- [ ] Check database performance
- [ ] Monitor user support tickets

### Rollback Plan
<!-- Describe how to rollback if needed -->

## Reviewer Guidelines

### Priority Review Areas
1. Security implementation
2. Database design
3. Error handling
4. Performance impact

### Questions for Reviewers
<!-- Ask specific questions you'd like reviewers to address -->
- ?
- ?

## Self-Review
I have reviewed my own code and confirmed:
- [ ] No obvious bugs or issues
- [ ] No security vulnerabilities
- [ ] Follows project conventions
- [ ] All acceptance criteria met
- [ ] No unnecessary changes included

## Additional Context
<!-- Any additional context for reviewers -->

---

### Quality Gate Status
- **Syntax Check**: ⏳ Pending
- **Security Scan**: ⏳ Pending  
- **Tests**: ⏳ Pending
- **Performance**: ⏳ Pending
- **Documentation**: ⏳ Pending

<!-- These will be updated by CI/CD -->
