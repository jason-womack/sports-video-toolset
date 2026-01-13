# Contributing to Sports Video Toolset

Thank you for your interest in contributing to the Sports Video Toolset! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and constructive
- Focus on what is best for the community
- Show empathy towards other contributors

## How to Contribute

### Reporting Issues

When reporting issues, please include:
- Script name and version
- Operating system and version
- FFmpeg version (`ffmpeg -version`)
- Complete command that caused the issue
- Error messages or unexpected behavior
- Expected behavior

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:
- Clear description of the enhancement
- Use cases and benefits
- Examples of how it would work
- Any potential drawbacks

### Contributing Code

#### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/sports-video-toolset.git
   cd sports-video-toolset
   ```

3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

#### Coding Standards

**Shell Script Guidelines:**

1. **Shebang**: Use `#!/usr/bin/env bash`

2. **Error Handling**: Always use `set -euo pipefail`

3. **Functions**: Document functions with comments
   ```bash
   # Process video with specific settings
   # Arguments:
   #   $1 - input file
   #   $2 - output file
   # Returns:
   #   0 on success, 1 on failure
   process_video() {
       local input="$1"
       local output="$2"
       # ...
   }
   ```

4. **Variables**:
   - Use lowercase with underscores for local variables: `local_variable`
   - Use UPPERCASE for constants: `CONSTANT_VALUE`
   - Quote variables: `"$variable"`
   - Use `local` for function variables

5. **Portability**:
   - Use POSIX-compatible commands when possible
   - Test on multiple platforms (Linux, macOS)
   - Avoid GNU-specific options without fallbacks
   - Use `command -v` instead of `which`

6. **Comments**:
   - Add comments for complex logic
   - Keep comments up-to-date with code
   - Document non-obvious behavior

7. **Error Messages**:
   - Use `log_error`, `log_warn`, `log_info`, `log_success` from video-utils.sh
   - Provide actionable error messages
   - Include context in error messages

8. **Testing**:
   - Test with various file formats (MP4, MKV, MOV)
   - Test with different codecs (H.264, H.265, VP9)
   - Test edge cases (empty files, missing metadata)
   - Verify output files are valid

#### Code Style Examples

**Good:**
```bash
#!/usr/bin/env bash
set -euo pipefail

process_file() {
    local input="$1"
    local output="$2"
    
    if [[ ! -f "$input" ]]; then
        log_error "Input file does not exist: $input"
        return 1
    fi
    
    log_info "Processing: $input"
    
    if ffmpeg -i "$input" -c copy "$output"; then
        log_success "Created: $output"
        return 0
    else
        log_error "Failed to process file"
        return 1
    fi
}
```

**Avoid:**
```bash
#!/bin/bash  # Use /usr/bin/env bash instead

process_file() {
    # Missing 'local' keyword
    input=$1
    output=$2
    
    # Unquoted variables
    if [ ! -f $input ]; then
        echo "Error"  # Use log_error
        return 1
    fi
    
    # No error handling
    ffmpeg -i $input -c copy $output
}
```

#### Pull Request Process

1. **Update documentation**: Update USAGE.md if adding features

2. **Test thoroughly**:
   ```bash
   # Test your changes
   ./bin/your-script --help
   ./bin/your-script test-input.mp4 test-output.mp4
   ```

3. **Check script with shellcheck** (if available):
   ```bash
   shellcheck bin/your-script
   ```

4. **Commit with clear messages**:
   ```bash
   git add bin/your-script docs/USAGE.md
   git commit -m "Add feature: brief description
   
   - Detailed point 1
   - Detailed point 2
   
   Fixes #issue-number"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create Pull Request**:
   - Provide clear title and description
   - Reference related issues
   - Describe what was changed and why
   - Include examples of usage

#### Pull Request Checklist

- [ ] Code follows project style guidelines
- [ ] Script includes help text (`--help`)
- [ ] Script uses video-utils.sh functions
- [ ] Script includes error handling
- [ ] Documentation updated (if needed)
- [ ] Changes tested on multiple file types
- [ ] Commit messages are clear and descriptive

## Project Structure

```
sports-video-toolset/
├── bin/                    # Executable scripts
│   ├── video-trim
│   ├── video-combine
│   ├── video-crop
│   ├── video-normalize
│   ├── video-prepare
│   └── video-info
├── lib/                    # Shared library functions
│   └── video-utils.sh
├── docs/                   # Documentation
│   ├── USAGE.md
│   └── CONTRIBUTING.md
├── examples/               # Example files and workflows
└── README.md              # Project overview
```

## Adding New Scripts

When adding a new script:

1. **Create script in `bin/`**:
   ```bash
   touch bin/video-newfeature
   chmod +x bin/video-newfeature
   ```

2. **Use template structure**:
   ```bash
   #!/usr/bin/env bash
   # video-newfeature - Brief description
   # Usage: video-newfeature INPUT OUTPUT
   
   set -euo pipefail
   
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
   
   # shellcheck source=../lib/video-utils.sh
   source "$LIB_DIR/video-utils.sh"
   
   usage() {
       cat <<EOF
   Usage: $(basename "$0") INPUT OUTPUT [OPTIONS]
   
   Brief description.
   
   Arguments:
       INPUT       Input description
       OUTPUT      Output description
   
   Options:
       -h, --help      Show this help message
       -f, --force     Overwrite output file if it exists
   
   Examples:
       $(basename "$0") input.mp4 output.mp4
   
   Notes:
       - Important note 1
       - Important note 2
   EOF
   }
   
   main() {
       # Implementation
       check_ffmpeg || exit 1
       check_ffprobe || exit 1
       
       # Process arguments
       # Validate inputs
       # Execute operation
       # Verify output
   }
   
   main "$@"
   ```

3. **Document in USAGE.md**:
   - Add to Scripts Overview table
   - Add detailed usage section
   - Add examples
   - Add to relevant workflows

4. **Test thoroughly** before submitting

## Adding Utility Functions

When adding functions to `lib/video-utils.sh`:

1. **Follow existing patterns**
2. **Document function purpose and parameters**
3. **Include error handling**
4. **Return appropriate exit codes**
5. **Use existing functions when possible**

Example:
```bash
# Get video aspect ratio
# Arguments:
#   $1 - input file path
# Returns:
#   Aspect ratio string (e.g., "16:9")
get_aspect_ratio() {
    local file="$1"
    
    if ! validate_input_file "$file"; then
        return 1
    fi
    
    ffprobe -v error -select_streams v:0 \
        -show_entries stream=display_aspect_ratio \
        -of default=noprint_wrappers=1:nokey=1 "$file"
}
```

## Documentation Guidelines

- Use clear, concise language
- Include examples for all features
- Keep documentation up-to-date
- Use proper Markdown formatting
- Include command output examples where helpful

## Testing

### Manual Testing

Test matrix for new features:

| Platform | Codec | Container | Result |
|----------|-------|-----------|--------|
| Linux    | H.264 | MP4       | ✓      |
| Linux    | H.265 | MP4       | ✓      |
| macOS    | H.264 | MOV       | ✓      |
| macOS    | H.265 | MP4       | ✓      |

### Test Cases

For each script, test:
1. Valid inputs
2. Missing arguments
3. Invalid file paths
4. Corrupted files
5. Various codecs and containers
6. Edge cases (very short/long files)
7. Special characters in filenames

## Getting Help

- Create an issue for questions
- Check existing issues and documentation
- Provide context and examples

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Recognition

Contributors are recognized in the project. Thank you for making this project better!

## Quick Contribution Checklist

- [ ] Feature/fix is well-defined
- [ ] Code follows style guidelines
- [ ] Script includes error handling
- [ ] Script tested with multiple file types
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] Ready for review

Thank you for contributing to Sports Video Toolset!
