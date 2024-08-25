// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Crowdfunding {
    // Struct to store project details
    struct Project {
        address payable creator;
        uint256 goalAmount;
        uint256 totalContributed;
        uint256 deadline;
        bool isFundingGoalMet;
        bool isCompleted;
    }

    // State variables
    uint256 public projectCount;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => mapping(address => uint256)) public contributors; // Track contributions

    // Events
    event ProjectCreated(uint256 projectId, address creator, uint256 goalAmount, uint256 deadline);
    event ContributionReceived(uint256 projectId, address contributor, uint256 amount);
    event FundsWithdrawn(uint256 projectId, address creator, uint256 amount);
    event RefundIssued(uint256 projectId, address contributor, uint256 amount);
    event ProjectCompleted(uint256 projectId);

    // Create a new project
    function createProject(uint256 _projectId, uint256 _goalAmount, uint256 _durationInDays) external {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(_projectId > 0, "Project ID must be greater than 0");
        require(projects[_projectId].creator == address(0), "Project ID already exists"); // Ensure the project ID is unique

        Project storage newProject = projects[_projectId];
        newProject.creator = payable(msg.sender);
        newProject.goalAmount = _goalAmount;
        newProject.deadline = block.timestamp + (_durationInDays * 1 days); // Convert days to seconds
        newProject.isFundingGoalMet = false;
        newProject.isCompleted = false;

        emit ProjectCreated(_projectId, msg.sender, _goalAmount, newProject.deadline);
    }

    // Contribute to a project
// Contribute to a project
function contribute(uint256 _projectId, uint256 _amount) external payable {
    Project storage project = projects[_projectId];
    require(block.timestamp < project.deadline, "Project funding has ended");
    require(_amount > 0, "Contribution must be greater than 0");
    require(msg.value >= _amount, "Insufficient funds sent"); // Check that sent funds are at least the specified amount

    project.totalContributed += _amount; // Add the contributed amount to the project's total
    contributors[_projectId][msg.sender] += _amount; // Track the amount contributed by the sender

    if (project.totalContributed >= project.goalAmount) {
        project.isFundingGoalMet = true; // Mark the project as funded if goal is met
    }

    // Refund any excess amount sent
    if (msg.value > _amount) {
        payable(msg.sender).transfer(msg.value - _amount);
    }

    emit ContributionReceived(_projectId, msg.sender, _amount); // Emit an event with the contribution details
}


    // Withdraw funds if the project goal is met
    function withdrawFunds(uint256 _projectId) external {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only the project creator can withdraw funds");
        require(project.isFundingGoalMet, "Funding goal not met");
        require(!project.isCompleted, "Project already completed");

        uint256 amount = project.totalContributed;
        project.totalContributed = 0;
        project.isCompleted = true;

        (bool success, ) = project.creator.call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(_projectId, msg.sender, amount);
        emit ProjectCompleted(_projectId);
    }

    // Refund contributors if the project fails to meet its goal
    function refund(uint256 _projectId) external {
        Project storage project = projects[_projectId];
        require(block.timestamp > project.deadline, "Project funding period not ended yet");
        require(!project.isFundingGoalMet, "Project goal was met, no refunds");

        uint256 contributedAmount = contributors[_projectId][msg.sender];
        require(contributedAmount > 0, "No funds to refund");

        contributors[_projectId][msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: contributedAmount}("");
        require(success, "Refund failed");

        emit RefundIssued(_projectId, msg.sender, contributedAmount);
    }

    // Function to view project details
    function getProjectDetails(uint256 _projectId) external view returns (
        address creator,
        uint256 goalAmount,
        uint256 totalContributed,
        uint256 deadline,
        bool isFundingGoalMet,
        bool isCompleted
    ) {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.goalAmount,
            project.totalContributed,
            project.deadline,
            project.isFundingGoalMet,
            project.isCompleted
        );
    }
}
