# Flutter Fixtures Example

This example demonstrates how to use the Flutter Fixtures library to mock HTTP requests in a Flutter application.

## Getting Started

1. Run the example app:
   ```
   flutter run
   ```

2. The app will show a basic example of using Flutter Fixtures with Dio.

3. You can select different selector types:
   - **Random**: Randomly selects a fixture response
   - **Default**: Always selects the fixture marked as default
   - **Pick**: Shows a dialog for the user to pick the response

4. Click the "Make Request" button to make a mock HTTP request.

## How It Works

The example app uses the Flutter Fixtures library to intercept HTTP requests made with Dio and return mock responses from fixture files.

### Fixture Files

The fixture files are located in the `assets/fixtures` directory:

- `POST_login.json`: Contains mock responses for the login endpoint
- `data/POST_login_success.json`: Contains the data for a successful login response

## Customizing the Example

You can customize the example by:

1. Adding more fixture files in the `assets/fixtures` directory
2. Modifying the existing fixture files
3. Changing the request parameters in the code

## Learn More

For more information about the Flutter Fixtures library, see the main README.
