// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface CategoryManagement {
    // Category-related functions
    function getCategoryInfo(uint256 categoryId) external view returns (uint256, uint256, string memory, string memory, uint256, uint256);
}

contract CategoryManagement is Ownable, ICategoryManagement {
    struct CategoryInfo {
        uint256 eventId;
        uint256 categoryId;
        string categoryName;
        string description;
        uint256 ticketPrice;
        uint256 numberOfTickets;
    }

    uint256 private categoryIdCounter;
    mapping(uint256 => CategoryInfo) private categories;

    function getCategoryInfo(uint256 categoryId) public view override returns (uint256, uint256, string memory, string memory, uint256, uint256) {
        CategoryInfo memory categoryInfo = categories[categoryId];
        require(categoryInfo.categoryId == categoryId, "Category does not exist");
        return (
            categoryInfo.eventId,
            categoryInfo.categoryId,
            categoryInfo.categoryName,
            categoryInfo.description,
            categoryInfo.ticketPrice,
            categoryInfo.numberOfTickets
        );
    }

    function createCategory(uint256 eventId, string memory categoryName, string memory description, uint256 ticketPrice, uint256 numberOfTickets) external onlyOwner {
        categoryIdCounter++;
        uint256 newCategoryId = categoryIdCounter;

        CategoryInfo memory newCategory = CategoryInfo({
            eventId: eventId,
            categoryId: newCategoryId,
            categoryName: categoryName,
            description: description,
            ticketPrice: ticketPrice,
            numberOfTickets: numberOfTickets
        });

        categories[newCategoryId] = newCategory;
    }
}