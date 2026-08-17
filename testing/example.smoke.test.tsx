// Example smoke test — copy to src/ (e.g. src/app/page.test.tsx), adapt, and delete this note.
// A smoke test proves the page renders without crashing. It's the floor, not the ceiling.
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';

// import Page from './page';

describe('smoke', () => {
  it('runs the test setup', () => {
    render(<div>hello</div>);
    expect(screen.getByText('hello')).toBeInTheDocument();
  });

  // it('renders the home page', () => {
  //   render(<Page />);
  //   expect(screen.getByRole('heading')).toBeInTheDocument();
  // });
});
