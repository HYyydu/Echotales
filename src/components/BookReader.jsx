import React, { useState, useEffect } from "react";
import bookService from "../services/bookService";
import "./BookReader.css";

const BookReader = ({ voiceId }) => {
  const [books, setBooks] = useState([]);
  const [filteredBooks, setFilteredBooks] = useState([]);
  const [selectedAge, setSelectedAge] = useState("all");
  const [selectedGenre, setSelectedGenre] = useState("All");
  const [searchQuery, setSearchQuery] = useState("");
  const [showFilterSheet, setShowFilterSheet] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const ageGroups = [
    { id: "all", label: "All Ages" },
    { id: "0-3", label: "0-3 years" },
    { id: "4-6", label: "4-6 years" },
    { id: "7-9", label: "7-9 years" },
    { id: "10-12", label: "10-12 years" },
    { id: "13+", label: "13+ years" },
  ];

  const genres = [
    "All",
    "Adventure",
    "Fantasy",
    "Fairy Tales",
    "Animals",
    "Science",
    "Mystery",
    "Friendship",
    "Family",
  ];

  // Fetch books from Firebase
  useEffect(() => {
    loadBooks();
  }, []);

  // Filter books - memoize to avoid unnecessary recalculations
  useEffect(() => {
    const filtered = books.filter((book) => {
      const matchesAge = selectedAge === "all" || book.age === selectedAge;
      const matchesGenre =
        selectedGenre === "All" || book.genre === selectedGenre;
      const matchesSearch =
        searchQuery === "" ||
        book.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        book.author.toLowerCase().includes(searchQuery.toLowerCase());

      return matchesAge && matchesGenre && matchesSearch;
    });
    setFilteredBooks(filtered);
  }, [books, selectedAge, selectedGenre, searchQuery]);

  const loadBooks = async () => {
    setLoading(true);

    // Start with sample data immediately for fast initial render
    setSampleBooks();
    setLoading(false);

    // Then try to fetch from Firebase in the background
    try {
      const fetchedBooks = await bookService.getAllBooks();
      if (fetchedBooks && fetchedBooks.length > 0) {
        setBooks(fetchedBooks);
      }
    } catch (err) {
      // Silently fail and keep using sample data
      console.log("Using sample data (Firebase not configured)");
    }
  };

  const setSampleBooks = () => {
    const sampleBooks = [
      {
        id: 1,
        title: "Wobbly",
        author: "Kanika ",
        age: "7-9",
        genre: "Adventure",
        coverUrl: "",
        tags: ["Bestseller"],
      },
      {
        id: 2,
        title: "Where the Wild Things Are",
        author: "Maurice Sendak",
        age: "4-6",
        genre: "Fantasy",
        coverUrl: "",
        tags: ["Classic"],
      },
      {
        id: 3,
        title: "Charlotte's Web",
        author: "E.B. White",
        age: "7-9",
        genre: "Animals",
        coverUrl: "",
        tags: ["Award Winner"],
      },
      {
        id: 4,
        title: "The Little Prince",
        author: "Antoine de Saint-Exupéry",
        age: "10-12",
        genre: "Fantasy",
        coverUrl: "",
        tags: ["Classic"],
      },
      {
        id: 5,
        title: "Goodnight Moon",
        author: "Margaret Wise Brown",
        age: "0-3",
        genre: "Bedtime",
        coverUrl: "",
        tags: ["Bedtime"],
      },
      {
        id: 6,
        title: "Harry Potter",
        author: "J.K. Rowling",
        age: "10-12",
        genre: "Fantasy",
        coverUrl: "",
        tags: ["Trending"],
      },
      {
        id: 7,
        title: "Matilda",
        author: "Roald Dahl",
        age: "7-9",
        genre: "Adventure",
        coverUrl: "",
        tags: ["Bestseller"],
      },
      {
        id: 8,
        title: "The Cat in the Hat",
        author: "Dr. Seuss",
        age: "4-6",
        genre: "Animals",
        coverUrl: "",
        tags: ["Classic"],
      },
      {
        id: 9,
        title: "Green Eggs and Ham",
        author: "Dr. Seuss",
        age: "4-6",
        genre: "Animals",
        coverUrl: "",
        tags: ["Classic"],
      },
    ];
    setBooks(sampleBooks);
    setLoading(false);
  };

  const hasActiveFilters = selectedAge !== "all" || selectedGenre !== "All";

  const resetFilters = () => {
    setSelectedAge("all");
    setSelectedGenre("All");
  };

  return (
    <div className="book-reader-page">
      {/* Status Bar */}
      <div className="status-bar">
        <div className="status-left">13:23 🌙</div>
        <div className="status-right">
          5G <span className="battery-icon">🔋</span>
        </div>
      </div>

      {/* Main Content */}
      <div className="main-content">
        {/* Header Section */}
        <div className="header-section">
          <h1>Discover Books</h1>

          {/* Search Bar + Filter Button */}
          <div className="search-row">
            <div className="search-bar">
              <span className="search-icon">🔍</span>
              <input
                type="text"
                placeholder="Search books, authors..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
              {searchQuery && (
                <button
                  className="clear-search"
                  onClick={() => setSearchQuery("")}
                >
                  ×
                </button>
              )}
            </div>
            <button
              className={`filter-button ${hasActiveFilters ? "active" : ""}`}
              onClick={() => setShowFilterSheet(true)}
            >
              ☰
            </button>
          </div>
        </div>

        {/* Active Filter Badges */}
        {hasActiveFilters && (
          <div className="active-filters">
            {selectedAge !== "all" && (
              <div className="filter-badge">
                {ageGroups.find((g) => g.id === selectedAge)?.label}
                <button onClick={() => setSelectedAge("all")}>×</button>
              </div>
            )}
            {selectedGenre !== "All" && (
              <div className="filter-badge">
                {selectedGenre}
                <button onClick={() => setSelectedGenre("All")}>×</button>
              </div>
            )}
          </div>
        )}

        {/* Results Count */}
        <div className="results-count">
          {filteredBooks.length} {filteredBooks.length === 1 ? "book" : "books"}{" "}
          found
        </div>

        {/* Books Grid */}
        {loading ? (
          <div className="loading">Loading books...</div>
        ) : filteredBooks.length === 0 ? (
          <div className="no-results">
            No books found matching your criteria
          </div>
        ) : (
          <div className="books-grid">
            {filteredBooks.map((book) => (
              <div key={book.id} className="book-card">
                {/* Book Cover */}
                <div className="book-cover">
                  {book.coverUrl ? (
                    <img src={book.coverUrl} alt={book.title} />
                  ) : (
                    <div className="placeholder-cover">📕</div>
                  )}
                  <div className="age-badge">{book.age}</div>
                </div>

                {/* Book Info */}
                <h3 className="book-title">{book.title}</h3>
                <p className="book-author">{book.author}</p>

                {/* Tags */}
                {book.tags && book.tags.length > 0 && (
                  <div className="book-tags">
                    {book.tags.map((tag, index) => (
                      <span key={index} className="tag">
                        {tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Filter Sheet */}
      {showFilterSheet && (
        <div
          className="filter-sheet-overlay"
          onClick={() => setShowFilterSheet(false)}
        >
          <div className="filter-sheet" onClick={(e) => e.stopPropagation()}>
            {/* Sheet Header */}
            <div className="sheet-header">
              <h2>Filter Books</h2>
              <button
                className="close-btn"
                onClick={() => setShowFilterSheet(false)}
              >
                ×
              </button>
            </div>

            <div className="sheet-content">
              {/* Age Group Section */}
              <div className="filter-section">
                <h3>Age Group</h3>
                <div className="filter-chips">
                  {ageGroups.map((age) => (
                    <button
                      key={age.id}
                      className={`filter-chip ${
                        selectedAge === age.id ? "active" : ""
                      }`}
                      onClick={() => setSelectedAge(age.id)}
                    >
                      {age.label}
                    </button>
                  ))}
                </div>
              </div>

              {/* Genre Section */}
              <div className="filter-section">
                <h3>Genre</h3>
                <div className="filter-chips">
                  {genres.map((genre) => (
                    <button
                      key={genre}
                      className={`filter-chip ${
                        selectedGenre === genre ? "active" : ""
                      }`}
                      onClick={() => setSelectedGenre(genre)}
                    >
                      {genre}
                    </button>
                  ))}
                </div>
              </div>

              {/* Reset Button */}
              <button className="reset-button" onClick={resetFilters}>
                Reset All Filters
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default BookReader;
