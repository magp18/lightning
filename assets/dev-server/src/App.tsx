import React from 'react';

import WorkflowDiagram from '../../js/workflow-diagram/src/WorkflowDiagram'
import useStore from './store'
import './main.css'

export default () => {
  const [history, setHistory ] = React.useState([])
  const [selectedNodes, setSelectedNodes ] = React.useState('')
  const workflow = useStore(
    ({ triggers, jobs, edges }) => ({ triggers, jobs, edges })
  );

  const handleSelectionChange = (ids: string[]) => {
    console.log(ids)
    setSelectedNodes(ids)
  }

  // Right now the diagram just supports the adding and removing of nodes,
  // so lets respect that
  const onNodeAdded = (from, data) => {
    // Add a node and a link to the store
  }

  const onNodeRemoved = (id) => {
    // remove a node and link from the store
  }

  return (<div className="flex flex-row h-full w-full">
    <div className="flex-1 border-2 border-slate-200 m-2 bg-secondary-100">
      <WorkflowDiagram 
        workflow={workflow}
        onSelectionChange={handleSelectionChange}
      />
    </div>
    <div className="flex-1 flex flex-col h-full w-1/3">
      <div className="flex-1 border-2 border-slate-200 m-2">
        <h2>Selected Node</h2>
        {/* Just show the node id here, it's more honest really */}
        { selectedNodes && <p>{selectedNodes}</p>}
      </div>
      <div className="flex-1 border-2 border-slate-200 m-2">Changes</div>
    </div>
  </div>
  );
};